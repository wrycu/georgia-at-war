#!/usr/local/bin/python3
import shutil
import pprint
import zipfile
import os
import random
import sys
import re
import requests
import datetime
import argparse
import subprocess
from metar import Metar

times = {
    'morning': 21600,  # 06:00
    'afternoon': 43200,  # 12:00
    'evening': 82800,  # 23:00
}

websocketReporter = "C:\\Users\\hoggit\\DCSUTILS\\Server_Scripts\\WebhookAlerter\\webhookAlerter.ps1"

parser = argparse.ArgumentParser(description="Split your DCS mission into different times, with weather from avwx")
parser.add_argument('-m', '--mission', required=True, help="The mission you want to split")
parser.add_argument('-i', '--icao', help="The ICAO designation of the airport to get weather for")
parser.add_argument('--metarout', help="Output the METAR string to this file. Ignored if not set")
parser.add_argument('-f', '--fallback', action='store_true',
                    help="Add this if you want to fall back to a default weather if no ICAO is found.\
                        If not specified, and no ICAO weather is found, we'll exit without doing anything")
parser.add_argument('-o', '--output', default=None, help="The directory to output the split missions to. Defaults to the current directory.")
parser.add_argument('-d', '--debug', action='store_true', help="More debug output")
parser.add_argument('-A', '--avwx_auth', help="Authentication to avwx.rest")

args = parser.parse_args()
is_debug = args.debug

def debug(str):
    if is_debug:
        log(str)

def log(str):
    print(str)

def change_mission_data(misFile, fn, descr, time, wx):
    today = datetime.datetime.now()
    start_time_regex = re.compile("^\s{4}\[\"start_time")
    date_regex_day = re.compile("^\s+\[\"Day")
    date_regex_month = re.compile("^\s+\[\"Month")
    date_regex_year = re.compile("^\s+\[\"Year")
    wind_rgx = re.compile("^\s{16}\[\"speed")
    wind_dir_rgx = re.compile("^\s{16}\[\"dir")
    if descr == 'morning':
        next_time = 'afternoon'
    elif descr == 'afternoon':
        next_time = 'evening'
    elif descr == 'evening':
    #     next_time = 'night'
    # elif descr == 'night':
        next_time = 'morning'

    next_file = "{0}_{1}.miz".format(fn[:-4], next_time)
    this_file = "{0}_{1}.miz.tmp".format(fn[:-4], descr)

    with open(misFile, encoding='utf-8') as fp:
        in_fog = False
        with open(this_file, 'w', encoding='utf-8') as tf:
            for line in fp:
                if '["fog"]' in line:
                    in_fog = True

                if '-- end of ["fog"]' in line:
                    in_fog = False

                if fn in line:
                    line = line.replace(fn, next_file)
                if not in_fog and '["thickness"]' in line:
                    line = '            ["thickness"] = {},\n'.format(wx['cloud_height'])
                if not in_fog and '["density"]' in line:
                    line = '            ["density"] = {},\n'.format(wx['cloud_density'])
                if '["base"]' in line:
                    line = '            ["base"] = {},\n'.format(wx['cloud_base'])
                if '["iprecptns"]' in line:
                    line = '            ["iprecptns"] = {},\n'.format(wx['precip'])
                if '["qnh"]' in line:
                    line = '        ["qnh"] = {},\n'.format(max(760, wx['pressure']))
                if '["temperature"]' in line:
                    line = '            ["temperature"] = {},\n'.format(wx['temp'])
                if wind_rgx.match(line):
                    line = '                ["speed"] = {},\n'.format(wx['wind_speed'])
                if wind_dir_rgx.match(line):
                    line = '                ["dir"] = {},\n'.format(wx['wind_dir'])
                if start_time_regex.match(line):
                    line = "    [\"start_time\"] = {},\n".format(time)
                if date_regex_year.match(line):
                    line = "         [\"Year\"] = {},\n".format(today.year)
                if date_regex_day.match(line):
                    line = "         [\"Day\"] = {},\n".format(today.day)
                if date_regex_month.match(line):
                    line = "         [\"Month\"] = {},\n".format(today.month)
                tf.write(line)

    return this_file

def cloud_map(sky):
    """
    Takes a list of tuples indicating cloud cover, generated from the Metar egg, and
    returns a list of tuples translated into DCS Cloud Cover and base height.

    Incoming Format ('BKN', <distance>, <something>)
    Outgoing Format ( 8, distance.value())

    If <distance> is Nil or falsey, we replace it with zero.
    The Outgoing format looks up the cloud density in the cloud_map var to determine the thickness between 0-10.
    """
    cloud_map = {
        'NSC': 0,
        'NCD': 0,
        'CLR': 0,
        'FEW': 2,
        'SCT': 6,
        'BKN': 8,
        'OVC': 10
    }
    return list(map(lambda s: (cloud_map[s[0]], s[1].value() if s[1] else 0), sky))

def thickest_clouds(cloud_thickness_and_base_list):
    """
    Given a list of tuples indicated cloud thickness and base, return the tuple
    with the thickest clouds
    """
    return max(cloud_thickness_and_base_list, key=lambda c: c[0])

def get_cloud_detail(sky):
    """
    Pull the thickest clouds from the Metar's sky list and return a dictionary
    with the following keys:
    "thickness": The cloud's thickness from 0-10 (for DCS).
    "base": the base height of the clouds
    """
    debug("Getting cloud details")
    clouds = cloud_map(sky)
    debug("There are {} clouds listed in the Metar".format(len(clouds)))
    thickest = thickest_clouds(clouds)
    debug("Found thickest clouds: thick: {} -- base {}".format(thickest[0], thickest[1]))
    return {
            "thickness": thickest[0],
            "base": thickest[1]
            }

def wind_speed_in_mps(wind):
    """
    Given a wind_speed object from a Metar, return the windspeed in meters per second format.
    """
    if wind._units == "KT":
        return wind.value() / 1.944
    if wind._units == "KPH":
        return wind.value() / 3.6
    if wind._units == "MPH":
        return wind.value() / 2.237
    return wind.value()


def handle_mission(fn, dest, weatherconf, fallback):
    def check_fallback():
        if not fallback:
            print("Fallback flag not specified, quitting.")
            sys.exit(1)
        else:
            print("Falling back to defaults")

    if os.path.exists(fn):
        path = os.path.abspath(fn)
        debug("path: {}".format(path))
        basedir = os.path.dirname(path)
        debug("basedir: {}".format(basedir))
        targetdir = "{}/.tmp".format(basedir)
        debug("targetdir: {}".format(targetdir))
        debug("Making tmp dir: {}".format(targetdir))
        if os.path.exists(targetdir):
            shutil.rmtree(targetdir)
        os.makedirs(targetdir)

        debug("Extracting zip: {}".format(fn))
        zip_ref = zipfile.ZipFile(fn, 'r')
        zip_ref.extractall(targetdir)

        misfile = "{}/mission".format(targetdir)

        # Get WX

        wx = {
            "temp": 23,
            "wind_speed": 4,
            "wind_dir": random.randint(250, 280),
            "cloud_base": 8000,
            "cloud_height": 1800,
            "cloud_density": 5,
            "precip": 0,
            "pressure": 760
        }
        try:
            authHeader = {"Authorization": weatherconf.authToken}
            wx_request = requests.get("https://avwx.rest/api/metar/" + weatherconf.icao.upper(), headers=authHeader, timeout = 5)
            if wx_request.status_code == 200:
                try:
                    wx_json = wx_request.json()
                    obs = Metar.Metar(wx_json['raw'], strict=False)
                    #obs = Metar.Metar("URKK 211400Z 33004MPS 290V360 CAVOK 30/18 Q1011 R23L/CLRD70 NOSIG RMK QFE755")
                    precip = 0
                    if obs.weather:
                        if obs.weather[0][2] == 'RA':
                            precip = 1
                        if obs.weather[0][1] == 'TS':
                            precip = 2

                    wx['temp'] = obs.temp.value()
                    wx['wind_speed'] = wind_speed_in_mps(obs.wind_speed)
                    if obs.wind_dir:
                        wx['wind_dir'] = (obs.wind_dir.value() + 180) % 360
                    if obs.sky:
                        clouds = get_cloud_detail(obs.sky)
                        wx['cloud_base'] = clouds["base"] * 0.3048 #METAR is Feet, Miz file expects meters
                        wx['cloud_height'] = 1800  * 0.3048 #METAR is Feet, Miz file expects meters
                        wx['cloud_density'] = clouds["thickness"]
                    else:
                        wx['cloud_base'] = 1800
                        wx['cloud_height'] = 1800
                        wx['cloud_density'] = 0
                    wx['precip'] = precip
                    wx['pressure'] = obs.press.value() / 1.33

                    print("----------------")
                    print(obs.code)
                    print("----------------")
                    if args.metarout:
                        metarfile = args.metarout
                        debug("metar outfile arg provided: {}".format(metarfile))
                        abs_path = os.path.abspath(metarfile)
                        path = os.path.dirname(abs_path)
                        print("path {}".format(path))
                        if not os.path.exists(path):
                            os.makedirs(path)
                        with open(abs_path, 'w', encoding='utf-8') as mf:
                            mf.write(obs.code)
                except Exception as e:
                    print(e)
                    print("FAILED TO GET DYNAMIC WEATHER")
                    subprocess.run(["powershell.exe", websocketReporter, "\"error\"", "\"mission splitter\"" , "\"FAILED TO GET DYNAMIC WEATHER\""])
                    check_fallback()
            else:
                print(wx_request)
                print("FAILED TO GET DYNAMIC WEATHER. METAR API UNAVAILABLE")
                subprocess.run(["powershell.exe", websocketReporter, "\"error\"", "\"mission splitter\"" , "\"FAILED TO GET DYNAMIC WEATHER. METAR API UNAVAILABLE\""])
                check_fallback()
        except Exception as e:
            print(e)
            print("Could not contact avwx for weather." )
            subprocess.run(["powershell.exe", websocketReporter, "\"error\"", "\"mission splitter\"" , "\"Could not contact avwx for weather.\""])
            check_fallback()

        new_files = []
        for descr, time in times.items():
            new_mis = change_mission_data(misfile, fn, descr, time, wx)
            debug("basedir: " + basedir)
            debug("fn: " + fn[:-4])
            debug("descr: " + descr)
            new_file = "{}/{}_{}".format(
                basedir,
                fn[:-4],
                descr
            )
            debug("targetdir " + targetdir)
            debug("new_file" + new_file)
            shutil.copytree(targetdir, new_file)
            shutil.move(new_mis, os.path.join(new_file, "mission"))
            shutil.make_archive(new_file, 'zip', new_file)
            new_files.append(new_file)

        new_dir = "{}/{}".format(basedir, fn)[:-4]
        debug("New dir: " + new_dir)
        if os.path.exists(new_dir) and os.path.isdir(new_dir):
            shutil.rmtree(new_dir)
        os.makedirs(new_dir)

        for new_file in new_files:
            filename = new_file+".zip"
            debug("new_file: " + new_file)
            debug("dest: " + dest)
            try:
                shutil.move(filename, os.path.join(dest, os.path.basename(new_file)+".miz"))
                print("Created {}".format(os.path.basename(new_file)+".miz"))
            except Exception as e:
                print("Couldn't move {} to {} . Skipping".format(filename, os.path.join(dest, os.path.basename(new_file)+".miz")))
                print(e)
            debug("Cleaning up zip: " + new_file)
            shutil.rmtree(new_file)

        #Clean up tmp dir.
        debug("Cleaning up " + targetdir)
        shutil.rmtree(targetdir)
        debug("Cleaning up " + new_dir)
        shutil.rmtree(new_dir)
    else:
        print("can't find {}".format(fn))

class WeatherConfig:
    def __init__(self, icao, authToken):
        self.icao = icao
        self.authToken = authToken

file = args.mission
icao = args.icao
avwx_auth = args.avwx_auth
weatherconf = WeatherConfig(icao, avwx_auth)
dest = args.output
fallback = args.fallback
debug("args: " + str(args))
handle_mission(file, dest, weatherconf, fallback)
print("Done.")
