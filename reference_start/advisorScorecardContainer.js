import { LightningElement } from 'lwc';

export default class AdvisorScorecardContainer extends LightningElement {

    // CSS Conic Gradients simulate the donut charts natively
    donutCharts = [
        { title: 'Revenue & Growth', value: '88%', style: 'background: conic-gradient(#0d7a42 88%, #e0e0e0 0);' },
        { title: 'Client Engagement', value: '82%', style: 'background: conic-gradient(#e2a024 82%, #e0e0e0 0);' },
        { title: 'Advisor Quality', value: '76%', style: 'background: conic-gradient(#103e7a 76%, #e0e0e0 0);' },
        { title: 'Adoption', value: '58%', style: 'background: conic-gradient(#c2272d 58%, #e0e0e0 0);' }
    ];

    priorityAlerts = [
        { count: 56, text: 'At-Risk Clients with No Contact in 6 Months' },
        { count: 34, text: 'Advisors with KYC Issues' },
        { count: 19, text: 'Reps Below Sales Targets' }
    ];

    advisorPerformance = [
        { label: 'Top Advisor', name: 'Sarah Mitchell', value: '$145,200,500 AUM', valueClass: 'slds-m-left_x-small' },
        { label: 'Rising Star', name: 'Alex Carter', value: '+32 New Clients', valueClass: 'slds-m-left_x-small' },
        { label: 'Lowest AUM Growth', name: 'Mike Johnson', value: '-2.1% in Qtr', valueClass: 'slds-m-left_x-small slds-text-color_error' }
    ];

    clientFocus = [
        { count: 23, text: 'Days Since Last Contact' },
        { count: null, text: 'KYC Review Due Soon' },
        { count: null, text: 'Investment Review Scheduled' }
    ];

    clientMetrics = [
        { id: '1', name: 'Sarah Mitchell', clients: 125, aum: '$145,200', growth: '89%', status: 'Compliant', iconName: 'action:approval', iconVariant: 'success' },
        { id: '2', name: 'Alex Carter', clients: 99, aum: '$87,4500', growth: '12%', status: 'Compliant', iconName: 'action:approval', iconVariant: 'success' },
        { id: '3', name: 'Lisa Nguyen', clients: 110, aum: '$1027,250', growth: '78%', status: 'Compliant', iconName: 'action:approval', iconVariant: 'success' },
        { id: '4', name: 'Mike Johnson', clients: 85, aum: '$56,320', growth: '64%', status: 'At Risk', iconName: 'action:close', iconVariant: 'error' }
    ];
}
