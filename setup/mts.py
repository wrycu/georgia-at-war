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
from configparser import ConfigParser
import random

times = {
    'morning': 21600,  # 06:00
    'afternoon': 43200,  # 12:00
    'evening': 82800,  # 23:00
}


def debug(str):
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
    load_next_miz_rgx = re.compile(r"^(.*a_load_mission\(\\\")(liberation.*.miz)(\\\"\).*)")
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
                if '["thickness"]' in line and wx['preset']:
                    line += f'\n\t\t\t["preset"] = "{wx["preset"]}",\n'
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
                if load_next_miz_rgx.match(line):
                    line = load_next_miz_rgx.sub(r'\1{}\3'.format(os.path.basename(next_file)), line)
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


def map_clouds_to_preset(clouds, rain):
    """
    :param clouds:
        Cloud cover as a number, from 0 to 10 (with 10 being overcast)
    :param rain:
        Rain amount. will be >0 if it's raining
    :return:
    """
    presets = {
        'clear': [
            None,     # None
            'Preset1',  # Light Scattered - 1
            'Preset2',  # Light Scattered - 2
        ],
        'few': [
            'Preset3',  # High Scattered - 1
            'Preset4',  # High Scattered - 2
            'Preset8',  # High Scattered - 3
        ],
        'scattered': [
            'Preset5',  # Scattered - 1
            'Preset6',  # Scattered - 2
            'Preset7',  # Scattered - 3
            'Preset9',  # Scattered - 4
            'Preset10',  # Scattered - 5
            'Preset11',  # Scattered - 6
            'Preset12',  # Scattered - 7
        ],
        'broken': [
            'Preset13',  # Broken - 1
            'Preset14',  # Broken - 2
            'Preset15',  # Broken - 3
            'Preset16',  # Broken - 4
            'Preset17',  # Broken - 5
            'Preset18',  # Broken - 6
            'Preset19',  # Broken - 7
            'Preset20',  # Broken - 8
        ],
        'overcast': [
            'Preset21',  # Overcast - 1
            'Preset22',  # Overcast - 2
            'Preset23',  # Overcast - 3
            'Preset24',  # Overcast - 4
            'Preset25',  # Overcast - 5
            'Preset26',  # Overcast - 6
            'Preset27',  # Overcast - 7
        ],
        'rain': [
            'RainyPreset1',  # Overcast and Rain - 1
            'RainyPreset2',  # Overcast and Rain - 2
            'RainyPreset3',  # Overcast and Rain - 3
        ],
    }

    debug("Determining preset - input data is " + str(clouds) + " " + str(rain))

    preset = None
    if rain:
        # rain
        preset = presets['rain'][random.randint(0, len(presets['rain']) - 1)]
    elif clouds == 0:
        # clear - randomly select from none and light scattered
        preset = presets['clear'][random.randint(0, len(presets['clear']) - 1)]
    elif clouds == 2:
        # few - randomly select from high scattered
        preset = presets['few'][random.randint(0, len(presets['few']) - 1)]
    elif clouds == 6:
        # scattered - randomly select from scattered
        preset = presets['scattered'][random.randint(0, len(presets['scattered']) - 1)]
    elif clouds == 8:
        # broken - randomly select from broken
        preset = presets['broken'][random.randint(0, len(presets['broken']) - 1)]
    elif clouds == 10:
        # overcast - randomly select from overcast
        preset = presets['overcast'][random.randint(0, len(presets['overcast']) - 1)]
    debug("Picked preset " + str(preset))
    return preset


def handle_mission(msn_file, dst_path, weatherconf):
    if os.path.exists(msn_file):
        path = os.path.abspath(msn_file)
        debug("path: {}".format(path))
        basedir = os.path.dirname(path)
        debug("basedir: {}".format(basedir))
        targetdir = os.path.join(basedir, '.tmp')
        debug("targetdir: {}".format(targetdir))
        debug("Making tmp dir: {}".format(targetdir))
        if os.path.exists(targetdir):
            shutil.rmtree(targetdir)
        os.makedirs(targetdir)

        debug("Extracting zip: {}".format(msn_file))
        zip_ref = zipfile.ZipFile(msn_file, 'r')
        zip_ref.extractall(targetdir)

        misfile = os.path.join(targetdir, "mission")

        # Get WX
        wx = {
            "temp": 23,
            "wind_speed": 4,
            "wind_dir": random.randint(250, 280),
            "cloud_base": 8000,
            "cloud_height": 1800,
            "cloud_density": 5,
            "precip": 0,
            "pressure": 760,
            "preset": None,
        }
        try:
            wx_request = requests.get(
                "https://avwx.rest/api/metar/" + weatherconf.icao.upper(),
                headers={"Authorization": weatherconf.authToken},
                timeout=5,
            )
            if wx_request.status_code == 200:
                try:
                    wx_json = wx_request.json()
                    obs = Metar.Metar(wx_json['raw'], strict=False)
                    precip = 0
                    if obs.weather:
                        if obs.weather[0][2] == 'RA':
                            precip = 1
                        if obs.weather[0][1] == 'TS':
                            precip = 2

                    wx['temp'] = obs.temp.value()
                    wx['wind_speed'] = wind_speed_in_mps(obs.wind_speed)
                    if obs.wind_dir:
                        # DCS uses wind in the direction it's going instead of where it's coming from
                        wx['wind_dir'] = (obs.wind_dir.value() + 180) % 360
                    if obs.sky:
                        clouds = get_cloud_detail(obs.sky)
                        wx['preset'] = map_clouds_to_preset(clouds['thickness'], precip)
                        wx['cloud_base'] = clouds["base"] * 0.3048  # METAR is Feet, Miz file expects meters
                        wx['cloud_height'] = 1800 * 0.3048          # METAR is Feet, Miz file expects meters
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
                except Exception as e:
                    print(e)
                    print("FAILED TO GET DYNAMIC WEATHER")
            else:
                print(wx_request)
                print("FAILED TO GET DYNAMIC WEATHER. METAR API UNAVAILABLE")
        except Exception as e:
            print(e)
            print("Could not contact avwx for weather.")

        new_files = []
        for descr, time in times.items():
            new_mis = change_mission_data(misfile, msn_file, descr, time, wx)
            debug("basedir: " + basedir)
            debug("fn: " + msn_file[:-4])
            debug("descr: " + descr)
            new_file = "{}/{}_{}".format(
                basedir,
                os.path.basename(msn_file)[:-4],
                descr
            )
            debug("targetdir " + targetdir)
            debug("new_file" + new_file)
            shutil.copytree(targetdir, new_file)
            shutil.move(new_mis, os.path.join(new_file, "mission"))
            shutil.make_archive(new_file, 'zip', new_file)
            new_files.append(new_file)

        new_dir = os.path.join(basedir, os.path.basename(msn_file)[:-4])
        debug("New dir: " + new_dir)
        if os.path.exists(new_dir) and os.path.isdir(new_dir):
            shutil.rmtree(new_dir)
        os.makedirs(new_dir)

        for new_file in new_files:
            filename = new_file+".zip"
            debug("new_file: " + new_file)
            debug("dest: " + dst_path)
            try:
                shutil.move(filename, os.path.join(dst_path, os.path.basename(new_file) + ".miz"))
                print("Created {}".format(os.path.basename(new_file)+".miz"))
            except Exception as e:
                print("Couldn't move {} to {} . Skipping".format(filename, os.path.join(dst_path, os.path.basename(new_file) + ".miz")))
                print(e)
            debug("Cleaning up zip: " + new_file)
            shutil.rmtree(new_file)

        #Clean up tmp dir.
        debug("Cleaning up " + targetdir)
        shutil.rmtree(targetdir)
        debug("Cleaning up " + new_dir)
        shutil.rmtree(new_dir)
    else:
        print("can't find {}".format(msn_file))


class WeatherConfig:
    def __init__(self, icao, authToken):
        self.icao = icao
        self.authToken = authToken


parser = ConfigParser()
parser.read('config.ini')
conf = {
    'api_token': parser.get('wx', 'token'),
    'mission_file': parser.get('script', 'mission'),
    'output_dir': parser.get('script', 'output'),
    'icao': parser.get('script', 'icao'),
}

random.seed()

handle_mission(
    conf['mission_file'],
    conf['output_dir'],
    WeatherConfig(
        conf['icao'],
        conf['api_token']
    ),
)
print("Done.")
