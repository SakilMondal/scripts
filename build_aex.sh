TG_BOT_API_KEY=$BOT_API_KEY
TG_CHAT_ID=436196117

#detect path where the script is running
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
if [ -z "$SCRIPT_DIR" ] ; then
    # error; for some reason, the path is not accessible
    echo "${red}Can not read run path"
    echo "Build can not continue"${txtrst}
    exit 1  # fail
fi

# Source common functions
source "${SCRIPT_DIR}"/common

trap 'exit 1' INT TERM

# Create binaries directory
mkdir -p ~/bin/

# Specify colors utilized in the terminal
red=$(tput setaf 1)                        #  red
grn=$(tput setaf 2)                        #  green
ylw=$(tput setaf 3)                        #  yellow
blu=$(tput setaf 4)                        #  blue
cya=$(tput rev)$(tput bold)$(tput setaf 6) #  bold cyan reversed
ylr=$(tput rev)$(tput bold)$(tput setaf 3) #  bold yellow reversed
grr=$(tput rev)$(tput bold)$(tput setaf 2) #  bold green reversed
rer=$(tput rev)$(tput bold)$(tput setaf 1) #  bold red reversed
txtrst=$(tput sgr0)                        #  Reset

[[ -z "${1}" ]] && echo "Device code name not passed as parameter, exiting!" && exit 1
DEVICE=$1

[[ -z "${TG_BOT_API_KEY}" ]] && echo "BOT_API_KEY not defined, exiting!" && exit 1
function sendTG() {
	curl -s "https://api.telegram.org/bot${TG_BOT_API_KEY}/sendmessage" --data "text=${*}&chat_id=${TG_CHAT_ID}&parse_mode=Markdown" >/dev/null
}

function urlencode() {
    # urlencode <string>
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    
    LC_COLLATE=$old_lc_collate
}

config=$SCRIPT_DIR"/config.conf"

if [ ! -f $config ]; then
    echo "Configuration file is missing"
    echo "Creating..."
	echo "Please enter the path where AEX folder is located (full path ex:/home/<user>/aex)"
	read aex_path
    echo "Upload compilation to remote server at end of build?"
	set_upload_build=false
	select yn in "Yes" "No"; do
		case $yn in
		Yes)
			set_upload_build=true
			break
			;;
		No)
			set_upload_build=false
			break
			;;
		esac
	done

	if [ "$set_upload_build" = true ]; then
		echo 'Please choose where to upload your build: '
		options=("Gdrive" "Source Forge")
		select opt in "${options[@]}"; do
			case $opt in
			"Gdrive")
				set_upload_build_server="gdrive"
				echo "Checking gdrive installed or not"
				GDRIVE="$(command -v gdrive)"
				if [ -z "${GDRIVE}" ]; then
					echo "Installing gdrive"
					bash -i "${SCRIPT_DIR}"/gdrive.sh
				else
					INSTALLED_VERSION="$(gdrive version | grep gdrive | awk '{print $2}')"
					reportWarning "gdrive ${INSTALLED_VERSION} is already installed!"
				fi
				break
				;;
			"Source Forge")
				echo "Comming soon..."
				# echo "Enter remote hostname (ex: web.sourceforge.net): "
				# read set_remote_hostname
				# echo "Enter remote username:"
				# read set_remote_username
				# echo "Enter remote password:"
				# read set_remote_password
				break
				;;
			esac
		done
	fi
	
	echo "${blu}Run repo sync?${txtrst}"
	select yn in "Yes" "No"; do
		case $yn in
		Yes)
			repo_sync = true
			break
			;;
		No) break ;;
		esac
	done

	echo "${blu}Select Build Type?${txtrst}"
	select yn in "eng" "userdebug" "user"; do
		case $yn in
		eng)
			device_build_type=aosp_${DEVICE}-eng
			break
			;;
		userdebug)
			device_build_type=aosp_${DEVICE}-userdebug
			break
			;;
		user)
			device_build_type=aosp_${DEVICE}-user
			break
			;;
		esac
	done

    #create config file
    echo "aex_path="$aex_path >> config.conf
    echo "set_upload_build="$set_upload_build >> config.conf
    echo "set_upload_build_server="$set_upload_build_server >> config.conf
	echo "repo_sync="$repo_sync >> config.conf
	echo "device_build_type="$device_build_type >> config.conf
    echo "${grn}Successfully created configuration file at ${ylw}$SCRIPT_DIR/config.conf${txtrst}"
fi
#read configuration
source config.conf

echoText "Changing dir to ${aex_path}"
cd $aex_path

# Check aex version
aex_check=$(grep -n "EXTENDED_VERSION" $aex_path/vendor/aosp/config/version.mk | grep -Eo '^[^:]+')
array=($aex_check)
AEX_VERSION=$(sed -n ${array[0]}'p' <$aex_path/vendor/aosp/config/version.mk | cut -d "=" -f 2 | tr -d '[:space:]')

if [ -z "$AEX_VERSION" ] || [ -z "$aex_check" ]; then
  echo -e ${red}"Couldn't detect AEX version exiting...."${txtrst};
  exit 1
fi

if [ "$repo_sync" = true ]; then
repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
fi

echo "${blu}Gapps or Non-gapps Build?${txtrst}"
select yn in "gapps" "nongapps"; do
	case $yn in
	gapps)
		export CURRENT_BUILD_TYPE=gapps
		break
		;;
	nongapps)
		export CURRENT_BUILD_TYPE=xyzzzz
		break
		;;
	esac
done

echo "${blu}OFFICIAL or UNOFFICIAL Build?${txtrst}"
select yn in "OFFICIAL" "UNOFFICIAL"; do
	case $yn in
	OFFICIAL)
		export EXTENDED_BUILD_TYPE=OFFICIAL
		break
		;;
	UNOFFICIAL)
		export EXTENDED_BUILD_TYPE=UNOFFICIAL
		break
		;;
	esac
done

source build/envsetup.sh

echo "${blu}Make clean build?${txtrst}"
select yn in "yes" "no"; do
	case $yn in
	yes)
		cd $aex_path
		make clean
		break
		;;
	no) break ;;
	esac
done

export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G # 50 GB
export CCACHE_DIR=~/sakil/ccache
cd $aex_path
if ! lunch "${device_build_type:?}"; then
	echo "Lunching $DEVICE failed"
	sendTG "Lunching $mydevice failed."
	exit 1
fi

echo "${blu}Please confirm do you want to start build?${txtrst}"
select yn in "yes" "no"; do
	case $yn in
	yes)
		cd $aex_path
		echo "${ylw}Initiating AEX ${AEX_VERSION} build for ${DEVICE}...${txtrst}"
		if ! mka aex; then
			echo "$DEVICE Build failed"
			sendTG "$DEVICE build failed."
			exit 1
		else
			cd $aex_path/out/target/product/$DEVICE
			ZIP=$(ls AospExtended-${AEX_VERSION}-$DEVICE-*.zip)
			ZIP_SIZE="$(du -h "${ZIP}" | awk '{print $1}')"
			MD5="$(md5sum "${ZIP}" | awk '{print $1}')"
			if [ "$set_upload_build" = true -a "$set_upload_build_server" == "gdrive" ]; then
				# Upload file
			GDRIVE_UPLOAD_URL=$(gdrive upload --share $ZIP -p 1GxPAlSxIt9txvMK8CqkJTwH59qZfAqmN | awk '/https/ {print $7}')
			GDRIVE_UPLOAD_ID="$(echo "${GDRIVE_UPLOAD_URL}" | sed -r -e 's/(.*)&export.*/\1/' -e 's/https.*id=(.*)/\1/' -e 's/https.*\/d\/(.*)\/view/\1/')"

        if [ -z "$GDRIVE_UPLOAD_URL" ] || [ -z "$GDRIVE_UPLOAD_ID" ]; then
            echo -e ${cya}"Couldn't upload build...."${txtrst};
            sendTG "$DEVICE build is done, but couldn't upload."
        else
			GDINDEX_URL="https://downloads.sakilmondal.me/Roms/$(urlencode $(basename "${ZIP}"))"
            UPLOAD_INFO="File: [$(basename "${ZIP}")](${GDINDEX_URL})
Size: ${ZIP_SIZE}
MD5: \`${MD5}\`
GDrive ID: \`${GDRIVE_UPLOAD_ID}\`"
		    sendTG "${UPLOAD_INFO}"
        fi
			else
				sendTG "$DEVICE build is done."
			fi
		fi
		break
		;;
	no) break ;;
	esac
done
