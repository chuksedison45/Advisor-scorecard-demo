public with sharing class AdvisorDashboardController {

    // 1. Wrapper Class to hold all dashboard data
    public class DashboardPayload {
        @AuraEnabled public Map<String, Decimal> kpis;
        @AuraEnabled public List<ChartItem> donutCharts;
        @AuraEnabled public PipelineMetric pipeline;
        @AuraEnabled public List<AlertItem> priorityAlerts;
        @AuraEnabled public List<AdvisorPerformanceItem> advisorPerformance;
        @AuraEnabled public List<FocusItem> clientFocus;
        @AuraEnabled public List<ClientMetric> clientMetrics;
        @AuraEnabled public List<CompliancePillar> compliancePillars;
        @AuraEnabled public List<ScorecardAdvisorMetric> scorecardMetrics;
        @AuraEnabled public Map<String, String> reportIds;
    }

    // Sub-wrappers for specific UI elements
    public class ChartItem {
        @AuraEnabled public String title;
        @AuraEnabled public Decimal percentage; // e.g., 88.0
        @AuraEnabled public String colorHex;
    }

    public class CompliancePillar {
        @AuraEnabled public String pillar;
        @AuraEnabled public Integer green;
        @AuraEnabled public Integer amber;
        @AuraEnabled public Integer red;
        @AuraEnabled public String callout;
    }

    public class ScorecardAdvisorMetric {
        @AuraEnabled public String advisorName;
        @AuraEnabled public String scorecardStatus;
        @AuraEnabled public Decimal overallScore;
        @AuraEnabled public String clientEngagement;
        @AuraEnabled public String revenueGrowth;
        @AuraEnabled public String advisorQuality;
        @AuraEnabled public String adoption;
        @AuraEnabled public String scoreMonth;
    }

    public class AlertItem {
        @AuraEnabled public Integer count;
        @AuraEnabled public String text;
    }

    public class PipelineMetric {
        @AuraEnabled public Integer openOpportunityCount;
        @AuraEnabled public Decimal openPipelineAmount;
        @AuraEnabled public String reportId;
    }

    public class AdvisorPerformanceItem {
        @AuraEnabled public String label;
        @AuraEnabled public String name;
        @AuraEnabled public String value;
        @AuraEnabled public String valueClass;
    }

    public class FocusItem {
        @AuraEnabled public Integer count;
        @AuraEnabled public String text;
    }

    public class ClientMetric {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer clients;
        @AuraEnabled public Decimal aum;
        @AuraEnabled public Decimal growth;
        @AuraEnabled public String status;
    }

    private static Map<String, String> getDashboardReportIds() {
        Map<String, String> reportKeyByDeveloperName = new Map<String, String>{
            'Total_Advisors_Report' => 'totalAdvisors',
            'Total_Clients_Report' => 'totalClients',
            'Total_AUM_Report' => 'totalAum',
            'Active_Households_Report' => 'activeHouseholds',
            'Total_Pipeline_Report' => 'totalPipeline',
            'IWAG_Revenue_Growth_Scorecard_Report' => 'Revenue & Growth',
            'IWAG_Client_Engagement_Scorecard_Report' => 'Client Engagement',
            'IWAG_Advisor_Quality_Scorecard_Report' => 'Advisor Quality',
            'IWAG_Adoption_Scorecard_Report' => 'Adoption'
        };
        Map<String, String> reportIds = new Map<String, String>();
        for (Report rpt : [SELECT Id, DeveloperName FROM Report WHERE DeveloperName IN :reportKeyByDeveloperName.keySet()]) {
            reportIds.put(reportKeyByDeveloperName.get(rpt.DeveloperName), rpt.Id);
        }
        return reportIds;
    }

    // 2. The Main Method called by LWC
    @AuraEnabled(cacheable=true)
    public static DashboardPayload getFullDashboardData() {
        DashboardPayload payload = new DashboardPayload();

        // --- A. Query KPIs ---
        List<String> clientAccountTypes = new List<String>{'Customer - Direct', 'Customer - Channel'};
        Integer totalClients = [SELECT COUNT() FROM Account WHERE Type IN :clientAccountTypes];
        AggregateResult[] aumResult = [SELECT SUM(AnnualRevenue) totalAum FROM Account WHERE Type IN :clientAccountTypes];
        Decimal totalAum = (Decimal)aumResult[0].get('totalAum');
        Integer totalAdvisors = [SELECT COUNT() FROM User WHERE IsActive = true AND UserType = 'Standard'];
        Integer activeHouseholds = [SELECT COUNT() FROM Account WHERE Type = null OR Type = 'Household'];

        payload.kpis = new Map<String, Decimal>();
        payload.kpis.put('totalAdvisors', totalAdvisors);
        payload.kpis.put('totalClients', totalClients);
        payload.kpis.put('totalAum', totalAum != null ? totalAum : 0);
        payload.kpis.put('activeHouseholds', activeHouseholds);
        payload.reportIds = getDashboardReportIds();

        // --- B. Generate Donut Chart Data ---
        Integer revenueAboveThreshold = [SELECT COUNT() FROM Account WHERE Type IN :clientAccountTypes AND AnnualRevenue >= 1000000];
        Integer engagedClients = [SELECT COUNT() FROM Account WHERE Type IN :clientAccountTypes AND LastActivityDate >= LAST_N_DAYS:30];
        Integer qualityClients = [SELECT COUNT() FROM Account WHERE Type IN :clientAccountTypes AND CustomerPriority__c = 'High'];
        Integer adoptionClients = [SELECT COUNT() FROM Account WHERE Type IN :clientAccountTypes AND UpsellOpportunity__c = 'Yes'];

        Decimal revenuePercent = totalClients > 0 ? ((Decimal)revenueAboveThreshold / totalClients) * 100 : 0;
        Decimal engagementPercent = totalClients > 0 ? ((Decimal)engagedClients / totalClients) * 100 : 0;
        Decimal qualityPercent = totalClients > 0 ? ((Decimal)qualityClients / totalClients) * 100 : 0;
        Decimal adoptionPercent = totalClients > 0 ? ((Decimal)adoptionClients / totalClients) * 100 : 0;

        payload.donutCharts = new List<ChartItem>();

        ChartItem revChart = new ChartItem();
        revChart.title = 'Revenue & Growth';
        revChart.percentage = revenuePercent.setScale(0);
        revChart.colorHex = '#0d7a42';
        payload.donutCharts.add(revChart);

        ChartItem engageChart = new ChartItem();
        engageChart.title = 'Client Engagement';
        engageChart.percentage = engagementPercent.setScale(0);
        engageChart.colorHex = '#e2a024';
        payload.donutCharts.add(engageChart);

        ChartItem qualityChart = new ChartItem();
        qualityChart.title = 'Advisor Quality';
        qualityChart.percentage = qualityPercent.setScale(0);
        qualityChart.colorHex = '#103e7a';
        payload.donutCharts.add(qualityChart);

        ChartItem adoptionChart = new ChartItem();
        adoptionChart.title = 'Adoption';
        adoptionChart.percentage = adoptionPercent.setScale(0);
        adoptionChart.colorHex = '#c2272d';
        payload.donutCharts.add(adoptionChart);

        // --- B2. Total Pipeline & Open Opportunity Data ---
        Integer openOpportunityCount = [SELECT COUNT() FROM Opportunity WHERE IsClosed = false];
        AggregateResult[] pipelineAmountResult = [SELECT SUM(Amount) totalPipeline FROM Opportunity WHERE IsClosed = false];
        Decimal pipelineAmount = pipelineAmountResult.isEmpty() ? 0 : (Decimal)pipelineAmountResult[0].get('totalPipeline');

        payload.pipeline = new PipelineMetric();
        payload.pipeline.openOpportunityCount = openOpportunityCount;
        payload.pipeline.openPipelineAmount = pipelineAmount != null ? pipelineAmount : 0;
        payload.pipeline.reportId = '00O_TotalPipeline_Rep_ID';

        // --- B3. Scorecard Compliance / Advisor Performance & Client Focus ---
        Date currentMonth = Date.today().toStartOfMonth();
        List<IWAG_Scorecard__c> scorecards = [
            SELECT Id,
                   Name,
                   Advisor__r.Name,
                   Scorecard_Month__c,
                   Scorecard_Status__c,
                   Overall_Score_KPI__c,
                   Client_Engagement_RAG__c,
                   Revenue_Growth_RAG__c,
                   Advisor_Quality_RAG__c,
                   Adoption_Rag__c
            FROM IWAG_Scorecard__c
            WHERE Scorecard_Month__c = :currentMonth
            ORDER BY Overall_Score_KPI__c DESC, Advisor__r.Name ASC
        ];

        if(scorecards.isEmpty()) {
            scorecards = [
                SELECT Id,
                       Advisor__r.Name,
                       Scorecard_Month__c,
                       Scorecard_Status__c,
                       Overall_Score_KPI__c,
                       Client_Engagement_RAG__c,
                       Revenue_Growth_RAG__c,
                       Advisor_Quality_RAG__c,
                       Adoption_Rag__c,
                       Name
                FROM IWAG_Scorecard__c
                WHERE Scorecard_Month__c >= :currentMonth.addMonths(-6)
                ORDER BY Scorecard_Month__c DESC, Overall_Score_KPI__c DESC, Advisor__r.Name ASC
                LIMIT 20
            ];
        }
        if(scorecards.isEmpty()) {
            scorecards = [
                SELECT Id,
                       Advisor__r.Name,
                       Scorecard_Month__c,
                       Scorecard_Status__c,
                       Overall_Score_KPI__c,
                       Client_Engagement_RAG__c,
                       Revenue_Growth_RAG__c,
                       Advisor_Quality_RAG__c,
                       Adoption_Rag__c,
                       Name
                FROM IWAG_Scorecard__c
                ORDER BY Scorecard_Month__c DESC, Overall_Score_KPI__c DESC, Advisor__r.Name ASC
                LIMIT 20
            ];
        }

        Map<String, IWAG_Scorecard__c> advisorScorecardMap = new Map<String, IWAG_Scorecard__c>();
        Map<String, Integer> advisorGreenCounts = new Map<String, Integer>();
        Map<String, Integer> advisorRedCounts = new Map<String, Integer>();
        Integer totalClientEngagementGreen = 0;
        Integer totalClientEngagementAmber = 0;
        Integer totalClientEngagementRed = 0;
        Integer totalRevenueGreen = 0;
        Integer totalRevenueAmber = 0;
        Integer totalRevenueRed = 0;
        Integer totalQualityGreen = 0;
        Integer totalQualityAmber = 0;
        Integer totalQualityRed = 0;
        Integer totalAdoptionGreen = 0;
        Integer totalAdoptionAmber = 0;
        Integer totalAdoptionRed = 0;

        for(IWAG_Scorecard__c sc : scorecards) {
            String advisorName = sc.Advisor__r != null ? sc.Advisor__r.Name : 'Unassigned Advisor';
            if(!advisorScorecardMap.containsKey(advisorName)) {
                advisorScorecardMap.put(advisorName, sc);
            }
            if(!advisorGreenCounts.containsKey(advisorName)) {
                advisorGreenCounts.put(advisorName, 0);
            }
            if(!advisorRedCounts.containsKey(advisorName)) {
                advisorRedCounts.put(advisorName, 0);
            }

            if(sc.Client_Engagement_RAG__c == 'Green') {
                totalClientEngagementGreen++;
                advisorGreenCounts.put(advisorName, advisorGreenCounts.get(advisorName) + 1);
            } else if(sc.Client_Engagement_RAG__c == 'Amber') {
                totalClientEngagementAmber++;
            } else if(sc.Client_Engagement_RAG__c == 'Red') {
                totalClientEngagementRed++;
                advisorRedCounts.put(advisorName, advisorRedCounts.get(advisorName) + 1);
            }

            if(sc.Revenue_Growth_RAG__c == 'Green') {
                totalRevenueGreen++;
                advisorGreenCounts.put(advisorName, advisorGreenCounts.get(advisorName) + 1);
            } else if(sc.Revenue_Growth_RAG__c == 'Amber') {
                totalRevenueAmber++;
            } else if(sc.Revenue_Growth_RAG__c == 'Red') {
                totalRevenueRed++;
                advisorRedCounts.put(advisorName, advisorRedCounts.get(advisorName) + 1);
            }

            if(sc.Advisor_Quality_RAG__c == 'Green') {
                totalQualityGreen++;
                advisorGreenCounts.put(advisorName, advisorGreenCounts.get(advisorName) + 1);
            } else if(sc.Advisor_Quality_RAG__c == 'Amber') {
                totalQualityAmber++;
            } else if(sc.Advisor_Quality_RAG__c == 'Red') {
                totalQualityRed++;
                advisorRedCounts.put(advisorName, advisorRedCounts.get(advisorName) + 1);
            }

            if(sc.Adoption_Rag__c == 'Green') {
                totalAdoptionGreen++;
                advisorGreenCounts.put(advisorName, advisorGreenCounts.get(advisorName) + 1);
            } else if(sc.Adoption_Rag__c == 'Amber') {
                totalAdoptionAmber++;
            } else if(sc.Adoption_Rag__c == 'Red') {
                totalAdoptionRed++;
                advisorRedCounts.put(advisorName, advisorRedCounts.get(advisorName) + 1);
            }
        }

        payload.compliancePillars = new List<CompliancePillar>();

        CompliancePillar clientEngagementPillar = new CompliancePillar();
        clientEngagementPillar.pillar = 'Client Engagement';
        clientEngagementPillar.green = totalClientEngagementGreen;
        clientEngagementPillar.amber = totalClientEngagementAmber;
        clientEngagementPillar.red = totalClientEngagementRed;
        clientEngagementPillar.callout = 'Based on scorecard engagement thresholds.';
        payload.compliancePillars.add(clientEngagementPillar);

        CompliancePillar revenueGrowthPillar = new CompliancePillar();
        revenueGrowthPillar.pillar = 'Revenue & Growth';
        revenueGrowthPillar.green = totalRevenueGreen;
        revenueGrowthPillar.amber = totalRevenueAmber;
        revenueGrowthPillar.red = totalRevenueRed;
        revenueGrowthPillar.callout = 'Revenue growth compliance across advisors.';
        payload.compliancePillars.add(revenueGrowthPillar);

        CompliancePillar advisorQualityPillar = new CompliancePillar();
        advisorQualityPillar.pillar = 'Advisor Quality';
        advisorQualityPillar.green = totalQualityGreen;
        advisorQualityPillar.amber = totalQualityAmber;
        advisorQualityPillar.red = totalQualityRed;
        advisorQualityPillar.callout = 'Advisor quality trend status.';
        payload.compliancePillars.add(advisorQualityPillar);

        CompliancePillar adoptionPillar = new CompliancePillar();
        adoptionPillar.pillar = 'Adoption';
        adoptionPillar.green = totalAdoptionGreen;
        adoptionPillar.amber = totalAdoptionAmber;
        adoptionPillar.red = totalAdoptionRed;
        adoptionPillar.callout = 'Digital adoption and activity-driven score compliance.';
        payload.compliancePillars.add(adoptionPillar);

        payload.scorecardMetrics = new List<ScorecardAdvisorMetric>();
        for(IWAG_Scorecard__c sc : scorecards) {
            ScorecardAdvisorMetric scorecardMetric = new ScorecardAdvisorMetric();
            scorecardMetric.advisorName = sc.Advisor__r != null ? sc.Advisor__r.Name : sc.Name;
            scorecardMetric.scorecardStatus = sc.Scorecard_Status__c != null ? sc.Scorecard_Status__c : 'Draft';
            scorecardMetric.overallScore = sc.Overall_Score_KPI__c != null ? sc.Overall_Score_KPI__c : 0;
            scorecardMetric.clientEngagement = sc.Client_Engagement_RAG__c;
            scorecardMetric.revenueGrowth = sc.Revenue_Growth_RAG__c;
            scorecardMetric.advisorQuality = sc.Advisor_Quality_RAG__c;
            scorecardMetric.adoption = sc.Adoption_Rag__c;
            scorecardMetric.scoreMonth = sc.Scorecard_Month__c != null ? sc.Scorecard_Month__c.format() : 'Unknown';
            payload.scorecardMetrics.add(scorecardMetric);
        }

        payload.advisorPerformance = new List<AdvisorPerformanceItem>();
        if(!scorecards.isEmpty()) {
            String topComplianceAdvisor = 'N/A';
            Integer topComplianceCount = -1;
            String mostAtRiskAdvisor = 'N/A';
            Integer mostRiskCount = -1;

            for(String advisorName : advisorGreenCounts.keySet()) {
                Integer greens = advisorGreenCounts.get(advisorName);
                if(greens > topComplianceCount) {
                    topComplianceCount = greens;
                    topComplianceAdvisor = advisorName;
                }
            }
            for(String advisorName : advisorRedCounts.keySet()) {
                Integer reds = advisorRedCounts.get(advisorName);
                if(reds > mostRiskCount) {
                    mostRiskCount = reds;
                    mostAtRiskAdvisor = advisorName;
                }
            }

            AdvisorPerformanceItem topScoreItem = new AdvisorPerformanceItem();
            topScoreItem.label = 'Highest Score';
            topScoreItem.name = !scorecards.isEmpty() ? String.valueOf(scorecards[0].Advisor__r != null ? scorecards[0].Advisor__r.Name : 'Unassigned Advisor') : 'N/A';
            topScoreItem.value = !scorecards.isEmpty() ? scorecards[0].Overall_Score_KPI__c.setScale(0, RoundingMode.HALF_UP) + '%' : '—';
            topScoreItem.valueClass = !scorecards.isEmpty() && scorecards[0].Overall_Score_KPI__c >= 90 ? 'slds-text-color_success' : 'slds-m-left_x-small';
            payload.advisorPerformance.add(topScoreItem);

            AdvisorPerformanceItem bestComplianceItem = new AdvisorPerformanceItem();
            bestComplianceItem.label = 'Top Compliance Advisor';
            bestComplianceItem.name = topComplianceAdvisor;
            bestComplianceItem.value = topComplianceCount >= 0 ? String.valueOf(topComplianceCount) + ' Green Pillars' : '—';
            bestComplianceItem.valueClass = 'slds-m-left_x-small';
            payload.advisorPerformance.add(bestComplianceItem);

            AdvisorPerformanceItem riskAdvisorItem = new AdvisorPerformanceItem();
            riskAdvisorItem.label = 'Most At Risk';
            riskAdvisorItem.name = mostAtRiskAdvisor;
            riskAdvisorItem.value = mostRiskCount > 0 ? String.valueOf(mostRiskCount) + ' Red Pillars' : 'None';
            riskAdvisorItem.valueClass = mostRiskCount > 0 ? 'slds-text-color_error slds-m-left_x-small' : 'slds-text-color_success slds-m-left_x-small';
            payload.advisorPerformance.add(riskAdvisorItem);
        } else {
            AggregateResult[] topAdvisorResults = [
                SELECT Owner.Name advisorName, SUM(AnnualRevenue) totalAum
                FROM Account
                WHERE Type IN :clientAccountTypes
                GROUP BY Owner.Name
                ORDER BY SUM(AnnualRevenue) DESC
                LIMIT 1
            ];
            AdvisorPerformanceItem topAdvisorItem = new AdvisorPerformanceItem();
            topAdvisorItem.label = 'Top Advisor';
            topAdvisorItem.name = !topAdvisorResults.isEmpty() ? String.valueOf(topAdvisorResults[0].get('advisorName')) : 'N/A';
            topAdvisorItem.value = !topAdvisorResults.isEmpty()
                ? '$' + String.valueOf(((Decimal)topAdvisorResults[0].get('totalAum')).setScale(0, RoundingMode.HALF_UP)) + ' AUM'
                : '—';
            topAdvisorItem.valueClass = 'slds-m-left_x-small';
            payload.advisorPerformance.add(topAdvisorItem);

            AggregateResult[] risingStarResults = [
                SELECT Owner.Name advisorName, COUNT(Id) newClients
                FROM Account
                WHERE Type IN :clientAccountTypes AND CreatedDate = LAST_N_DAYS:30
                GROUP BY Owner.Name
                ORDER BY COUNT(Id) DESC
                LIMIT 1
            ];
            AdvisorPerformanceItem risingStarItem = new AdvisorPerformanceItem();
            risingStarItem.label = 'Rising Star';
            risingStarItem.name = !risingStarResults.isEmpty() ? String.valueOf(risingStarResults[0].get('advisorName')) : 'N/A';
            risingStarItem.value = !risingStarResults.isEmpty()
                ? '+' + String.valueOf(((Decimal)risingStarResults[0].get('newClients')).intValue()) + ' New Clients'
                : '—';
            risingStarItem.valueClass = 'slds-m-left_x-small';
            payload.advisorPerformance.add(risingStarItem);

            AggregateResult[] lowestGrowthResults = [
                SELECT Owner.Name advisorName, COUNT(Id) activeClients
                FROM Account
                WHERE Type IN :clientAccountTypes AND LastActivityDate >= LAST_N_DAYS:90
                GROUP BY Owner.Name
                ORDER BY COUNT(Id) ASC
                LIMIT 1
            ];
            AdvisorPerformanceItem lowGrowthItem = new AdvisorPerformanceItem();
            lowGrowthItem.label = 'Lowest AUM Growth';
            lowGrowthItem.name = !lowestGrowthResults.isEmpty() ? String.valueOf(lowestGrowthResults[0].get('advisorName')) : 'N/A';
            lowGrowthItem.value = !lowestGrowthResults.isEmpty()
                ? '-' + String.valueOf(((Decimal)lowestGrowthResults[0].get('activeClients')).intValue()) + ' Active Clients'
                : '—';
            lowGrowthItem.valueClass = 'slds-m-left_x-small slds-text-color_error';
            payload.advisorPerformance.add(lowGrowthItem);
        }

        payload.clientFocus = new List<FocusItem>();

        FocusItem noContactFocus = new FocusItem();
        noContactFocus.count = [
            SELECT COUNT()
            FROM Account
            WHERE Type IN :clientAccountTypes AND LastActivityDate < LAST_N_DAYS:30
        ];
        noContactFocus.text = 'Days Since Last Contact';
        payload.clientFocus.add(noContactFocus);

        FocusItem kycReview = new FocusItem();
        kycReview.count = [
            SELECT COUNT()
            FROM Account
            WHERE Type IN :clientAccountTypes AND SLAExpirationDate__c <= NEXT_N_DAYS:30
        ];
        kycReview.text = 'KYC Review Due Soon';
        payload.clientFocus.add(kycReview);

        FocusItem investmentReview = new FocusItem();
        investmentReview.count = [
            SELECT COUNT()
            FROM Account
            WHERE Type IN :clientAccountTypes AND UpsellOpportunity__c = 'Yes'
        ];
        investmentReview.text = 'Investment Review Scheduled';
        payload.clientFocus.add(investmentReview);

        // --- C. Query Alerts ---
        payload.priorityAlerts = new List<AlertItem>();

        AlertItem noContactAlert = new AlertItem();
        noContactAlert.count = [SELECT COUNT() FROM Account WHERE Type IN :clientAccountTypes AND LastActivityDate < LAST_N_DAYS:180];
        noContactAlert.text = 'At-Risk Clients with No Contact in 6 Months';
        payload.priorityAlerts.add(noContactAlert);

        AlertItem kycAlert = new AlertItem();
        kycAlert.count = [SELECT COUNT() FROM Account WHERE Type IN :clientAccountTypes AND SLAExpirationDate__c < TODAY];
        kycAlert.text = 'Advisors with KYC Issues';
        payload.priorityAlerts.add(kycAlert);

        AlertItem belowTargetAlert = new AlertItem();
        belowTargetAlert.count = [SELECT COUNT() FROM Account WHERE Type IN :clientAccountTypes AND AnnualRevenue < 250000];
        belowTargetAlert.text = 'Reps Below Sales Targets';
        payload.priorityAlerts.add(belowTargetAlert);

        // --- D. Query Table Metrics (List of Accounts/Advisors) ---
        payload.clientMetrics = new List<ClientMetric>();

        List<AggregateResult> advisorMetrics = [
            SELECT Advisor_Name__c advisorName,
                   Owner.Name ownerName,
                   COUNT(Id) clients,
                   SUM(AnnualRevenue) totalAum,
                   MAX(LastActivityDate) lastActivityDate,
                   MAX(Rating) latestRating
            FROM Account
            WHERE Type IN :clientAccountTypes
            GROUP BY Advisor_Name__c, Owner.Name
            ORDER BY SUM(AnnualRevenue) DESC
            LIMIT 5
        ];

        for(AggregateResult ar : advisorMetrics) {
            ClientMetric metric = new ClientMetric();
            String advisorName = ar.get('advisorName') != null ? String.valueOf(ar.get('advisorName')) : null;
            if(String.isBlank(advisorName)) {
                advisorName = ar.get('ownerName') != null ? String.valueOf(ar.get('ownerName')) : 'Unassigned Advisor';
            }
            metric.id = advisorName;
            metric.name = advisorName;
            metric.clients = ar.get('clients') != null ? ((Decimal)ar.get('clients')).intValue() : 0;
            metric.aum = ar.get('totalAum') != null ? (Decimal)ar.get('totalAum') : 0;

            Date lastActivity = (Date)ar.get('lastActivityDate');
            Integer daysSinceContact = lastActivity != null ? Math.abs(Date.today().daysBetween(lastActivity)) : 999;
            Integer growthPercent = daysSinceContact <= 30 ? 82 : daysSinceContact <= 60 ? 48 : 14;
            metric.growth = growthPercent;

            IWAG_Scorecard__c matchingScorecard = advisorScorecardMap.containsKey(advisorName) ? advisorScorecardMap.get(advisorName) : null;
            if(matchingScorecard != null) {
                metric.status = matchingScorecard.Scorecard_Status__c != null ? matchingScorecard.Scorecard_Status__c : 'Compliant';
            } else {
                String latestRating = ar.get('latestRating') != null ? String.valueOf(ar.get('latestRating')) : null;
                metric.status = latestRating != null && latestRating != 'null'
                    ? latestRating
                    : (daysSinceContact > 60 ? 'At Risk' : 'Compliant');
            }

            payload.clientMetrics.add(metric);
        }

        return payload;
    }
}
