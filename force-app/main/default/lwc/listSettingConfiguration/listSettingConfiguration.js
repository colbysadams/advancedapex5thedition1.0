import { LightningElement } from 'lwc';
import getCSListObject from '@salesforce/apex/ConfigSettingController.getCSListObject';
import saveCSListObject from '@salesforce/apex/ConfigSettingController.saveCSListObject';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ListSettingConfiguration extends LightningElement {
    currentAppConfig = null;
    originalAppConfig = null;

    get appenabled() { return (this.currentAppConfig!=null && this.currentAppConfig.AppEnabled__c) };
    
    changeEnabled(event) {
        this.currentAppConfig.AppEnabled__c = event.target.checked;
    }

    get enablediagnostics() { return (this.currentAppConfig!=null && this.currentAppConfig.EnableDiagnostics__c) };
    
    changeDiagnostics(event) {
        this.currentAppConfig.EnableDiagnostics__c = event.target.checked;
    }

    connectedCallback() {
        this.loadObjectValues();
    }

    loadObjectValues() {
        getCSListObject({'settingName':'default'}).then (result => {
            this.currentAppConfig = result[0];
            this.originalAppConfig = result[1];
        })
    }

    handleClick()
    {
        saveCSListObject({'configObject': this.currentAppConfig, 
                'originalObject': this.originalAppConfig, 'settingName': 'default'}).then (result=> {
                this.loadObjectValues();
                this.showToast('Success', 'Configuration saved');
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