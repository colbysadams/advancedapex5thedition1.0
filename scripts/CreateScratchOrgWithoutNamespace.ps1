# This batch file creates a default scratch org without a namespace using the sfdx-project.json file
sfdx force:org:create -s -f config/project-scratch-def.json -a ch12nons --nonamespace
sfdx force:source:push -u ch12nons