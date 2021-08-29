# This batch file creates a multicurrency scratch org without a namespace using the sfdx-project.json file
sfdx force:org:create -f config/project-scratch-mc.json -a ch12mc --nonamespace
sfdx force:source:push -u ch12mc
