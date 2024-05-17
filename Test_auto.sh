#!/bin/bash


YELLOW='\033[1m\033[38;2;255;255;0m'
RED='\033[1m\033[38;2;255;0;0m'
RESET='\033[0m'


WARNING="${YELLOW}[WARNING]${RESET}"
FAILED="${RED}[FAILED]${RESET}"
INFO="${YELLOW}[INFO]${RESET}"


check_library_installed() {
  dpkg -s "$1" &> /dev/null
  return $?
}


read -p "enter filename to check for libraries: " filename


if [ ! -f "$filename" ]; then
  echo -e "$FAILED file not found"
  exit 1
fi


libraries=()
libs_in_file=$(grep -oP '#include\s*<\K[^>]*' "$filename")
for lib in $libs_in_file; do
  libraries+=("$lib")
done


libraries=($(printf "%s\n" "${libraries[@]}" | sort -u))

# report 
report_file="library_report.txt"
echo "library installation report" > "$report_file"
echo "===========================" >> "$report_file"


for lib in "${libraries[@]}"; do
  echo -e "$INFO checking for library $lib..."
  pkg_name=$(echo "$lib" | sed 's/\./-/g') 
  check_library_installed "$pkg_name"
  if [ $? -eq 0 ]; then
    version=$(dpkg -s "$pkg_name" | grep '^Version' | awk '{print $2}')
    echo "library $lib is installed :: version: $version" >> "$report_file"
  else
    echo -e "$FAILED library $lib not found"
    echo "library $lib is not installed" >> "$report_file"
    read -p "please provide the download URL for $lib: " url
    download_path="./$lib.deb"
    
    echo "downloading $lib from $url..."
    wget -O "$download_path" "$url"
    if [ $? -eq 0 ]; then
      echo "installing $lib..."
      sudo dpkg -i "$download_path"
      if [ $? -eq 0 ]; then
        version=$(dpkg -s "$pkg_name" | grep '^Version' | awk '{print $2}')
        echo "library $lib installed successfully :: Version: $version" >> "$report_file"
      else
        echo -e "$FAILED there was an issue installing $lib"
        echo "library $lib installation failed" >> "$report_file"
      fi
    else
      echo -e "$FAILED there was an issue downloading $lib."
      echo "library $lib download failed." >> "$report_file"
    fi
  fi
done


cat "$report_file"
