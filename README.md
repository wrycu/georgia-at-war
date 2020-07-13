## Local Development
1. From your install folder (not saved games), open scripts/MissionScripting.lua
2. Comment out all the lines in the do block below the sanitization function with "-\-".  This allows the lua engine access to the file system. It should look similar to:

        --sanitizeModule('os')
	    --sanitizeModule('io')
	    --sanitizeModule('lfs')
	    --require = nil
	    --loadlib = nil
3. Clone this repo.  From your `Saved Games\DCS.openbeta\Scripts` folder run `git clone https://gitlab.com/hoggit/developers/georgia-at-war.git GAW`.  This should create a folder named `GAW` and in the end it should look like `Saved Games\DCS.openbeta\Scripts\GAW
`
4. Download the .miz file from [Dropbox](https://www.dropbox.com/s/zy754dwcsg8jnor/Georgia%20At%20War%20v3.0.24.miz?dl=0)