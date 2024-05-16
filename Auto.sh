#!/bin/bash

# - Definitions
YELLOW='\033[1m\033[38;2;255;255;0m'
RED='\033[1m\033[38;2;255;0;0m'
RESET='\033[0m'

# - Log Terminal Messages
WARNING="${YELLOW}[WARNING]${RESET}"
FAILED="${RED}[FAILED]${RESET}"

# - Default Extensions List
EXTENSION_LIST=( "*.cpp" "*.hpp" )

# - User Extensions List
USER_EXTENSION_LIST=()

if [ ! -d "../build" ]; then
    mkdir ../build
else
    echo -e "$WARNING Build Directory Already Exists. Clearing the Build Directory."
    rm -rf ../build/*
fi

# - Copy Prepared CMakeLists.txt File to Root Directory
cp CMakeLists.txt ../

# - Go to Previous Directory
cd ..

# - Parse Input Options Using getopt
OPTS=$(getopt -o e:p: -l extensions:,packages: -n "$0" -- "$@")
eval set -- "$OPTS"
while true; do
  case "$1" in
    -e|--extensions)
      USER_EXTENSION_LIST+=("$2")
      shift 2
      ;;
    -p|--packages)
      PACKAGES="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo -e "$FAILED Invalid Option"
      exit 1
  esac
done

# Extract Extensions from the Command Line Arguments
for extended in "$@"; do
  if [[ "$extended" == *"."* ]]; then
    USER_EXTENSION_LIST+=("$extended")
  fi
done

# - Find All Files with Given Extensions
if [ ${#USER_EXTENSION_LIST[@]} -ne 0 ]; then
  find_expression=()
  for ext in "${USER_EXTENSION_LIST[@]}"; do
    find_expression+=("-name" "$ext" "-o")
  done
  find_expression=("${find_expression[@]:0:$((${#find_expression[@]}-1))}")
else
  find_expression=()
  for ext in "${EXTENSION_LIST[@]}"; do
    find_expression+=("-name" "$ext" "-o")
  done
  find_expression=("${find_expression[@]:0:$((${#find_expression[@]}-1))}")
fi
source_files=$(find . -type f \( "${find_expression[@]}" \))

# - Check if Source List is Empty
if [ -z "$source_files" ]; then
    echo -e "$WARNING No Files with Used Extensions Found in the Project Directory."
    exit 1
fi

# - detect libraries 
libraries=()
for file in $source_files; do
  libs_in_file=$(grep -oP '#include\s*<\K[^>]*' "$file")
  for lib in $libs_in_file; do
    libraries+=("$lib")
  done
done

# - remove duplicate libraries
libraries=($(printf "%s\n" "${libraries[@]}" | sort -u))

# - Change directory to the build folder
cd build

# - Run the CMake Command with the Source Files List
source_files=$(echo $source_files | tr ' ' ';')
cmake -D_SRC="$source_files" -D_USE_PACKAGES="$PACKAGES" ..
make

# - check libraries
make_output=$(make 2>&1)
missing_libs=$(echo "$make_output" | grep -oP '(?<=dont find -l)\w+')

# - echo url libs not found
for lib in $missing_libs; do
  if [[ " ${libraries[@]} " =~ " ${lib} " ]]; then
    echo -e "$FAILED library $lib not found."
    read -p "please enter the download URL for $lib: " url
    download_path="../build/$lib.deb"
    
    echo "downloading $lib from $url..."
    wget -O "$download_path" "$url"
    if [ $? -eq 0 ]; then
      echo "installing $lib..."
      sudo dpkg -i "$download_path"
      if [ $? -eq 0 ]; then
        echo "library $lib installed :)"
      else
        echo -e "$FAILED dont installed $lib."
      fi
    else
      echo -e "$FAILED dont installed $lib."
    fi
  fi
done

# Re-run make after installing missing libraries
make
