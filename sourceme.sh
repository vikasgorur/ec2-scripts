#!/bin/bash

# Begin user-editable section

# Change this to your name
export EC2_OWNER="Vikas"

# Name of the SSH key. A corresponding key file should exist in this directory.
# If the key name is "vikas", the file should be called "vikas.pem"
export EC2_SSH_KEY="vikas"

# End of user-editable section

export EC2_PRIVATE_KEY=`ls $PWD/pk-*.pem`
export EC2_CERT=`ls $PWD/cert-*.pem`
export AWS_HOME=$PWD

