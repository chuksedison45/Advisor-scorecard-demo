import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFullDashboardData from '@salesforce/apex/AdvisorDashboardController.getFullDashboardData';

const REPORT_IDS = {
    totalAdvisors: '00O_TotalAdvisors_Rep_ID',
    totalClients: '00O_TotalClients_Rep_ID',
    totalAum: '00O_TotalAUM_Rep_ID',
    activeHouseholds: '00O_ActiveHouseholds_Rep_ID',
    totalPipeline: '00O_TotalPipeline_Rep_ID',
    'Revenue & Growth': '00O_RevenueGrowth_Rep_ID',
    'Client Engagement': '00O_ClientEngagement_Rep_ID',
    'Advisor Quality': '00OgL00000Agn1lUAB',
    Adoption: '00O_Adoption_Rep_ID'
};

export default class AdvisorScorecardContainer extends NavigationMixin(LightningElement) {

    // Initialize empty properties to hold the dynamic data
    reportIds = {};
    kpis = [];
    donutCharts = [];
    pipelineData = {};
    priorityAlerts = [];
    advisorPerformance = [];
    clientFocus = [];
    clientMetrics = [];
    compliancePillars = [];
    scorecardMetrics = [];

    // The Master Wire Method
    @wire(getFullDashboardData)
    wiredDashboardData({ error, data }) {
        if (data) {
            const safeData = JSON.parse(JSON.stringify(data));
            this.reportIds = safeData.reportIds || {};
            this.processKpis(safeData.kpis);
            this.processCharts(safeData.donutCharts);
            this.pipelineData = {
                ...(safeData.pipeline || {}),
                reportId: this.getReportId('totalPipeline') || (safeData.pipeline && safeData.pipeline.reportId) || ''
            };
            this.priorityAlerts = safeData.priorityAlerts || [];
            this.advisorPerformance = safeData.advisorPerformance || [];
            this.clientFocus = safeData.clientFocus || [];
            this.processCompliancePillars(safeData.compliancePillars || []);
            this.processScorecardMetrics(safeData.scorecardMetrics || []);
            this.processTableMetrics(safeData.clientMetrics || []);
        } else if (error) {
            console.error('Error fetching full dashboard data', error);
        }
    }

    // --- Data Processing Helpers ---

    processKpis(kpiData = {}) {
        // Build the dynamic KPI cards, linking to report IDs
        this.kpis = [
            {
                id: 'kpi-advisors',
                label: 'Total Advisors',
                value: kpiData.totalAdvisors ? kpiData.totalAdvisors.toLocaleString() : '0',
                reportId: this.getReportId('totalAdvisors')
            },
            {
                id: 'kpi-clients',
                label: 'Total Clients',
                value: kpiData.totalClients ? kpiData.totalClients.toLocaleString() : '0',
                reportId: this.getReportId('totalClients')
            },
            {
                id: 'kpi-aum',
                label: 'Total AUM',
                value: kpiData.totalAum ? this.formatCurrency(kpiData.totalAum) : '$0',
                reportId: this.getReportId('totalAum')
            },
            {
                id: 'kpi-households',
                label: 'Active Households',
                value: kpiData.activeHouseholds ? kpiData.activeHouseholds.toLocaleString() : '0',
                reportId: this.getReportId('activeHouseholds')
            }
        ];
    }

    processCharts(chartData = []) {
        // Dynamically build the CSS style strings for the donut charts
        this.donutCharts = chartData.map(chart => {
            return {
                title: chart.title,
                value: `${chart.percentage}%`,
                style: `background: conic-gradient(${chart.colorHex} ${chart.percentage}%, #e0e0e0 0);`,
                reportId: this.getReportId(chart.title)
            };
        });
    }

    processTableMetrics(metricsData = []) {
        // Map the raw data and dynamically assign icons from actual status values
        this.clientMetrics = metricsData.map(metric => {
            const status = metric.status || 'Unknown';
            const icon = this.getStatusIcon(status);
            const rawGrowth = metric.growth != null ? metric.growth : 0;

            return {
                id: metric.id,
                name: metric.name,
                clients: metric.clients,
                aum: this.formatCurrency(metric.aum),
                growth: `${rawGrowth}%`,
                status,
                iconName: icon.iconName,
                iconVariant: icon.iconVariant
            };
        });
    }

    processCompliancePillars(pillarsData) {
        this.compliancePillars = pillarsData.map(pillar => {
            return {
                pillar: pillar.pillar,
                green: pillar.green,
                amber: pillar.amber,
                red: pillar.red,
                callout: pillar.callout
            };
        });
    }

    processScorecardMetrics(metricsData) {
        this.scorecardMetrics = metricsData.map(metric => {
            return {
                advisorName: metric.advisorName,
                scorecardStatus: metric.scorecardStatus,
                overallScore: metric.overallScore != null ? `${metric.overallScore}%` : 'N/A',
                clientEngagement: metric.clientEngagement,
                revenueGrowth: metric.revenueGrowth,
                advisorQuality: metric.advisorQuality,
                adoption: metric.adoption,
                scoreMonth: metric.scoreMonth,
                rowKey: `${metric.advisorName}-${metric.scoreMonth}`
            };
        });
    }

    getStatusIcon(status) {
        const normalized = status ? status.toLowerCase() : '';
        if (normalized.includes('red') || normalized.includes('at risk') || normalized.includes('risk')) {
            return { iconName: 'action:close', iconVariant: 'error' };
        }
        if (normalized.includes('amber') || normalized.includes('review') || normalized.includes('draft')) {
            return { iconName: 'utility:warning', iconVariant: 'warning' };
        }
        return { iconName: 'action:approval', iconVariant: 'success' };
    }

    getReportId(key) {
        return (this.reportIds && this.reportIds[key]) || REPORT_IDS[key] || '';
    }

    // --- Utilities & Navigation ---

    formatCurrency(value) {
        const amount = value != null ? Number(value) : 0;
        return new Intl.NumberFormat('en-US', {
            style: 'currency',
            currency: 'USD',
            maximumFractionDigits: 0
        }).format(amount);
    }

    get pipelineAmountText() {
        return this.pipelineData && this.pipelineData.openPipelineAmount
            ? this.formatCurrency(this.pipelineData.openPipelineAmount)
            : '$0';
    }

    handleNavigateToReport(event) {
        const reportTarget = event.currentTarget.dataset.reportId
            ? event.currentTarget
            : event.target.closest('[data-report-id]');
        const targetReportId = reportTarget ? reportTarget.dataset.reportId : null;

        if (targetReportId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: targetReportId,
                    objectApiName: 'Report',
                    actionName: 'view'
                }
            });
        }
    }
}


