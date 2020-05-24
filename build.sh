#!/bin/bash

python setup.py build_ext --inplace
while [ "$1" != "" ]; do
    case $1 in
        -t | --test)
            python -m unittest 
           ;;
        -h | --help)
            exit 1
            ;;
	-tv | --test-verbose)
      python -m unittest --verbose
		;;
        * )
            usage
            exit 1
    esac
    shift
done
