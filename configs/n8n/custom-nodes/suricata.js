// MI-SOAR-NGFW n8n Custom Node for Suricata
// Provides integration with Suricata IDS/IPS

module.exports = {
    name: 'Suricata',
    version: '1.0.0',
    description: 'Interact with Suricata IDS/IPS',
    icon: 'shield',
    group: ['transform'],
    subtitle: '{{$parameter["operation"]}}',
    defaults: {
        name: 'Suricata',
    },
    inputs: ['main'],
    outputs: ['main'],
    credentials: [
        {
            name: 'suricataApi',
            required: true,
        },
    ],
    properties: [
        {
            displayName: 'Operation',
            name: 'operation',
            type: 'options',
            options: [
                {
                    name: 'Add Rule',
                    value: 'addRule',
                    description: 'Add a new rule to Suricata',
                },
                {
                    name: 'Delete Rule',
                    value: 'deleteRule',
                    description: 'Delete a rule from Suricata',
                },
                {
                    name: 'Reload Rules',
                    value: 'reloadRules',
                    description: 'Reload Suricata rules',
                },
                {
                    name: 'Get Stats',
                    value: 'getStats',
                    description: 'Get Suricata statistics',
                },
                {
                    name: 'Block IP',
                    value: 'blockIP',
                    description: 'Block an IP address via Suricata',
                },
            ],
            default: 'getStats',
        },
        {
            displayName: 'Rule',
            name: 'rule',
            type: 'string',
            displayOptions: {
                show: {
                    operation: ['addRule'],
                },
            },
            default: '',
            description: 'Suricata rule to add',
        },
        {
            displayName: 'Rule ID',
            name: 'ruleId',
            type: 'string',
            displayOptions: {
                show: {
                    operation: ['deleteRule'],
                },
            },
            default: '',
            description: 'SID of the rule to delete',
        },
        {
            displayName: 'IP Address',
            name: 'ipAddress',
            type: 'string',
            displayOptions: {
                show: {
                    operation: ['blockIP'],
                },
            },
            default: '',
            description: 'IP address to block',
        },
        {
            displayName: 'Duration (seconds)',
            name: 'duration',
            type: 'number',
            displayOptions: {
                show: {
                    operation: ['blockIP'],
                },
            },
            default: 3600,
            description: 'How long to block the IP (in seconds)',
        },
    ],

    async execute() {
        const items = this.getInputData();
        const returnItems = [];

        for (let itemIndex = 0; itemIndex < items.length; itemIndex++) {
            const operation = this.getNodeParameter('operation', itemIndex);

            // TODO: Implement actual Suricata API integration
            // This is a placeholder implementation

            let result;
            switch (operation) {
                case 'addRule':
                    result = { success: true, message: 'Rule added (simulated)' };
                    break;
                case 'deleteRule':
                    result = { success: true, message: 'Rule deleted (simulated)' };
                    break;
                case 'reloadRules':
                    result = { success: true, message: 'Rules reloaded (simulated)' };
                    break;
                case 'getStats':
                    result = {
                        uptime: '5 days',
                        packets: 1504321,
                        alerts: 42,
                        memory: '256MB',
                    };
                    break;
                case 'blockIP':
                    result = { success: true, message: 'IP blocked (simulated)' };
                    break;
                default:
                    throw new Error(`Operation "${operation}" is not supported`);
            }

            returnItems.push({
                json: {
                    ...items[itemIndex].json,
                    suricataResult: result,
                },
            });
        }

        return this.prepareOutputData(returnItems);
    },
};