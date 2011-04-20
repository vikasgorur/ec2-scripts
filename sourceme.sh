#!/bin/bash

# Begin user-editable section
export ACCESS_KEY_ID="AKIAIDM26U6HBZN4HC4A"
export SECRET_ACCESS_KEY="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"

# Name of the SSH key. A corresponding key file should exist in this directory.
# If the key name is "vikas", the file should be called "vikas.pem"
export EC2_SSH_KEY="vikas"

# End of user-editable section

export EC2_PRIVATE_KEY=`ls $PWD/pk-*.pem`
export EC2_CERT=`ls $PWD/cert-*.pem`
export AWS_HOME=$PWD

