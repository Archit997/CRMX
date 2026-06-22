import '../models/crmx_models.dart';
import 'crmx_repository.dart';

class MockData {
  static const statuses = [
    StatusMaster(statusNo: 1, statusName: 'New Lead', category: 'Lead', description: ''),
    StatusMaster(statusNo: 6, statusName: 'Document Sent', category: 'Lead', description: ''),
    StatusMaster(statusNo: 7, statusName: 'Follow-up Required', category: 'Lead', description: ''),
    StatusMaster(statusNo: 8, statusName: 'Negotiation Phase', category: 'Client', description: ''),
    StatusMaster(statusNo: 9, statusName: 'Payment Pending', category: 'Client', description: ''),
    StatusMaster(statusNo: 10, statusName: 'Order Confirmed', category: 'Client', description: ''),
  ];

  static const dashboard = DashboardData(
    statuses: statuses,
    clients: [
      ClientInfo(
        clientId: 101,
        clientName: 'Aman Gupta',
        companyName: 'ABC Traders',
        phone: '9876543210',
        whatsappNumber: '9876543210',
        email: 'aman@abctraders.example',
        city: 'Delhi',
        assignedTo: 'Rohit',
        currentStatusNo: 8,
        statusName: 'Negotiation Phase',
        requirementSummary: 'Wants 500 units and is asking for bulk discount.',
        priority: 'Hot',
        dealValue: 470000,
        updates: [
          ClientUpdate(
            updateId: 501,
            clientId: 101,
            updateType: 'WhatsApp',
            newStatusNo: 8,
            note: 'Client asked for discount and earlier delivery.',
            followupDate: '2026-06-06',
            followupTime: '11:30',
            createdBy: 'Rohit',
          ),
        ],
      ),
      ClientInfo(
        clientId: 103,
        clientName: 'Vikram Jain',
        companyName: 'Jain Plastics',
        phone: '9222255555',
        whatsappNumber: '9222255555',
        email: 'vikram@jainplastics.example',
        city: 'Mumbai',
        assignedTo: 'Priya',
        currentStatusNo: 9,
        statusName: 'Payment Pending',
        requirementSummary: 'Advance payment pending before dispatch.',
        priority: 'Hot',
        dealValue: 240000,
      ),
    ],
    followUps: [
      FollowUpItem(
        clientId: 101,
        clientName: 'Aman Gupta',
        companyName: 'ABC Traders',
        priority: 'Hot',
        statusName: 'Negotiation Phase',
        note: 'Quotation review and discount decision pending.',
        followupDate: '2026-06-06',
        followupTime: '11:30',
        isOverdue: false,
      ),
    ],
    manager: ManagerSummary(
      calls: 67,
      whatsapp: 41,
      overdueFollowups: 1,
      quotedValue: 1375000,
      unloggedCalls: 11,
    ),
    receivables: [
      FinanceReceivable(
        clientName: 'Vikram Jain',
        companyName: 'Jain Plastics',
        amountDue: 240000,
        status: 'Payment Pending',
        action: 'Call before 2 PM for advance payment confirmation.',
      ),
      FinanceReceivable(
        clientName: 'Aman Gupta',
        companyName: 'ABC Traders',
        amountDue: 470000,
        status: 'Negotiation Phase',
        action: 'Confirm payment terms after revised quotation.',
      ),
    ],
    financeMessage: 'Today receivable follow-up:\n1. Jain Plastics: call before 2 PM.\n2. ABC Traders: confirm payment terms.',
    source: DataSource.mock,
  );
}
