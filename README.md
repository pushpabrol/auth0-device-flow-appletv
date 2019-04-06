# auth0-device-flow-appletv
auth0 device flow oauth2 appletv limited input device

## Overview
This is a simple apple tv sample that shows how auth0 can be used to authenticate using the Oauth2 device flow for limited input devices from an apple tv. In this sample after the user authenticates successfully they can view the video.

## Setup
- Change the Domain and ClientId in the Auth0.plist file
- Make sure the auth0 client supports the Device code grant type - `urn:ietf:params:oauth:grant-type:device_code`
- Run the sample to test in the apple tv simulator
