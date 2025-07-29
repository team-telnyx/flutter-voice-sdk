#!/bin/bash

rm Podfile.lock
pod repo update
pod install