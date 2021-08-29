# This batch file creates a scratch org with a namespace defined in the sfdx-project.json file
# Note that you must specify a valid namespace in that file. Refer to the Saleforce DX Developer guide chapter
# on second generation packages
sfdx force:org:create -s -f config/project-scratch-def.json -a ch12ns
sfdx force:source:push -u ch12ns
