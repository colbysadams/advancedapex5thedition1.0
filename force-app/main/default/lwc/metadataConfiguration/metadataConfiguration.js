import { LightningElement } from 'lwc';
import getCustomMetadataObjects from '@salesforce/apex/ConfigMetadataController.getCustomMetadataObjects';
import saveCustomMetadataObject from '@salesforce/apex/ConfigMetadataController.saveCustomMetadataObject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';

export default class MetadataConfiguration extends LightningElement {

    currentMDSetting = null;
    originalMDSetting = null;
    jobId = null;
    deploymentInProgress = false;

    get booleansetting() { return (this.currentMDSetting!=null && this.currentMDSetting.BooleanSetting__c) };
    
    changeBoolean(event) {
        this.currentMDSetting.BooleanSetting__c = event.target.checked;
    }

    get textsetting() { return (this.currentMDSetting!=null)? this.currentMDSetting.TextSetting__c : null; };
    
    changeText(event) {
        this.currentMDSetting.TextSetting__c = event.target.value;
    }

    connectedCallback() {
        this.loadObjectValues();
        this.subscribeToMetadataDeployEvent();
    }

    loadObjectValues() {
        getCustomMetadataObjects({'MDName':'default'}).then (result => {
            this.currentMDSetting = result[0];
            this.originalMDSetting = result[1];
        })
    }

    deploymentCompleteCallback = (response) => 
    {
        this.deploymentInProgress = false;
        let eventInfo = response.data.payload;
        if(eventInfo.JobID__c != this.jobId) return; // It's a different job
        if(eventInfo.Success__c)
        {
            this.showToast('Success', 'Configuration saved');
        }
        else
        {
            this.showToast('Error', eventInfo.ErrorMessage__c);
        }
        this.loadObjectValues();
    }

    // Callback invoked whenever a new event message is received
    subscribeToMetadataDeployEvent() {

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        subscribe('/event/MetadataDeployComplete__e', -1, this.deploymentCompleteCallback).then(response => {
            // Response contains the subscription information on subscribe call
            console.log('Subscription request sent to: ', JSON.stringify(response.channel));
            this.subscription = response;
        });    
    }

    handleClick()
    {
        saveCustomMetadataObject({'configObject': this.currentMDSetting, 
                'originalObject': this.originalMDSetting, 'MDName': 'default'}).then (result=> {
                this.jobId = result;
                this.deploymentInProgress = true;
        }).catch (err => {
            this.loadObjectValues();
            this.showToast('Error', err.body.message);
        })
    }

    showToast(ptitle, pmessage) {
        const event = new ShowToastEvent({
            title: ptitle,
            message: pmessage,
        });
        this.dispatchEvent(event);
    }

}