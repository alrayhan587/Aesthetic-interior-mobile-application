class ProcurementMetrics {
  final int totalRequisitions;
  final int submittedCount;
  final int inProcurementCount;
  final int fulfilledCount;
  final int activeProjectsCount;

  const ProcurementMetrics({
    required this.totalRequisitions,
    required this.submittedCount,
    required this.inProcurementCount,
    required this.fulfilledCount,
    required this.activeProjectsCount,
  });

  factory ProcurementMetrics.fromJson(Map<String, dynamic> json) {
    return ProcurementMetrics(
      totalRequisitions: (json['totalRequisitions'] as num?)?.toInt() ?? 0,
      submittedCount: (json['submittedCount'] as num?)?.toInt() ?? 0,
      inProcurementCount: (json['inProcurementCount'] as num?)?.toInt() ?? 0,
      fulfilledCount: (json['fulfilledCount'] as num?)?.toInt() ?? 0,
      activeProjectsCount: (json['activeProjectsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProcurementWalletSummary {
  final double advanceBalance;
  final double pendingReimbursement;
  final double totalSpent;

  const ProcurementWalletSummary({
    required this.advanceBalance,
    required this.pendingReimbursement,
    required this.totalSpent,
  });

  factory ProcurementWalletSummary.fromJson(Map<String, dynamic> json) {
    return ProcurementWalletSummary(
      advanceBalance: (json['advanceBalance'] as num?)?.toDouble() ?? 0.0,
      pendingReimbursement:
          (json['pendingReimbursement'] as num?)?.toDouble() ?? 0.0,
      totalSpent: (json['totalSpent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RequisitionLead {
  final String id;
  final String name;
  final String? phone;
  final String? location;

  const RequisitionLead({
    required this.id,
    required this.name,
    this.phone,
    this.location,
  });

  factory RequisitionLead.fromJson(Map<String, dynamic> json) {
    return RequisitionLead(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled Project',
      phone: json['phone'] as String?,
      location: json['location'] as String?,
    );
  }
}

class MaterialRequisitionSummary {
  final String id;
  final String requisitionNo;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final RequisitionLead lead;
  final String createdBy;
  final int totalItems;
  final int billedItems;
  final List<String> categories;

  const MaterialRequisitionSummary({
    required this.id,
    required this.requisitionNo,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.lead,
    required this.createdBy,
    required this.totalItems,
    required this.billedItems,
    required this.categories,
  });

  bool get isCompleted => status == 'FULFILLED';
  bool get isInProcurement => status == 'IN_PROCUREMENT';
  bool get isSubmitted => status == 'SUBMITTED';

  factory MaterialRequisitionSummary.fromJson(Map<String, dynamic> json) {
    return MaterialRequisitionSummary(
      id: json['id'] as String? ?? '',
      requisitionNo: json['requisitionNo'] as String? ?? '',
      status: json['status'] as String? ?? 'SUBMITTED',
      notes: json['notes'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      lead: json['lead'] is Map<String, dynamic>
          ? RequisitionLead.fromJson(json['lead'] as Map<String, dynamic>)
          : const RequisitionLead(id: '', name: 'Project'),
      createdBy: json['createdBy'] as String? ?? 'BOQ Team',
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      billedItems: (json['billedItems'] as num?)?.toInt() ?? 0,
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class ItemPurchaseRecord {
  final bool isBought;
  final String? supplierId;
  final String? supplierName;
  final double unitRate;
  final double purchasedQty;
  final double totalCost;
  final String? notes;
  final String? receiptUrl;

  const ItemPurchaseRecord({
    required this.isBought,
    this.supplierId,
    this.supplierName,
    required this.unitRate,
    required this.purchasedQty,
    required this.totalCost,
    this.notes,
    this.receiptUrl,
  });

  factory ItemPurchaseRecord.fromJson(Map<String, dynamic> json) {
    return ItemPurchaseRecord(
      isBought: json['isBought'] == true,
      supplierId: json['supplierId'] as String?,
      supplierName: json['supplierName'] as String?,
      unitRate: (json['unitRate'] as num?)?.toDouble() ?? 0.0,
      purchasedQty: (json['purchasedQty'] as num?)?.toDouble() ?? 0.0,
      totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
    );
  }
}

class MaterialRequisitionItemModel {
  final String id;
  final String requisitionId;
  final String workCategory;
  final String materialName;
  final String? specifications;
  final double netQuantity;
  final double wastagePercent;
  final double finalQuantity;
  final String unit;
  final Map<String, dynamic>? variantAttributes;
  final ItemPurchaseRecord? purchaseRecord;

  const MaterialRequisitionItemModel({
    required this.id,
    required this.requisitionId,
    required this.workCategory,
    required this.materialName,
    this.specifications,
    required this.netQuantity,
    required this.wastagePercent,
    required this.finalQuantity,
    required this.unit,
    this.variantAttributes,
    this.purchaseRecord,
  });

  bool get isBought => purchaseRecord?.isBought ?? false;

  factory MaterialRequisitionItemModel.fromJson(Map<String, dynamic> json) {
    final attrs = json['variantAttributes'] is Map<String, dynamic>
        ? json['variantAttributes'] as Map<String, dynamic>
        : null;

    ItemPurchaseRecord? purchase;
    if (attrs != null) {
      if (attrs['purchaseRecord'] is Map<String, dynamic>) {
        purchase = ItemPurchaseRecord.fromJson(
            attrs['purchaseRecord'] as Map<String, dynamic>);
      } else if (attrs['billingRecord'] is Map<String, dynamic>) {
        purchase = ItemPurchaseRecord.fromJson(
            attrs['billingRecord'] as Map<String, dynamic>);
      }
    }

    if (purchase == null) {
      if (json['purchaseRecord'] is Map<String, dynamic>) {
        purchase = ItemPurchaseRecord.fromJson(
            json['purchaseRecord'] as Map<String, dynamic>);
      } else if (json['billingRecord'] is Map<String, dynamic>) {
        purchase = ItemPurchaseRecord.fromJson(
            json['billingRecord'] as Map<String, dynamic>);
      }
    }

    return MaterialRequisitionItemModel(
      id: json['id'] as String? ?? '',
      requisitionId: json['requisitionId'] as String? ?? '',
      workCategory: json['workCategory'] as String? ?? 'CABINETS_CLOSETS',
      materialName: json['materialName'] as String? ?? 'Material Item',
      specifications: json['specifications'] as String?,
      netQuantity: (json['netQuantity'] as num?)?.toDouble() ?? 1.0,
      wastagePercent: (json['wastagePercent'] as num?)?.toDouble() ?? 0.0,
      finalQuantity: (json['finalQuantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'Pcs',
      variantAttributes: attrs,
      purchaseRecord: purchase,
    );
  }
}

class MaterialRequisitionDetail {
  final String id;
  final String requisitionNo;
  final String status;
  final String? notes;
  final RequisitionLead lead;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MaterialRequisitionItemModel> items;

  const MaterialRequisitionDetail({
    required this.id,
    required this.requisitionNo,
    required this.status,
    this.notes,
    required this.lead,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  int get billedItemsCount => items.where((i) => i.isBought).length;
  double get totalUnits =>
      items.fold(0.0, (sum, i) => sum + i.finalQuantity);

  factory MaterialRequisitionDetail.fromJson(Map<String, dynamic> json) {
    final leadMap = json['lead'] as Map<String, dynamic>?;
    final createdByMap = json['createdBy'] as Map<String, dynamic>?;
    final rawItems = json['items'] ??
        json['requisitionItems'] ??
        json['materialItems'] ??
        json['materials'];
    final itemsList = (rawItems as List<dynamic>?)
            ?.map((e) => MaterialRequisitionItemModel.fromJson(
                e as Map<String, dynamic>))
            .toList() ??
        [];

    return MaterialRequisitionDetail(
      id: json['id'] as String? ?? '',
      requisitionNo: json['requisitionNo'] as String? ?? '',
      status: json['status'] as String? ?? 'SUBMITTED',
      notes: json['notes'] as String?,
      lead: leadMap != null
          ? RequisitionLead.fromJson(leadMap)
          : const RequisitionLead(id: '', name: 'Project'),
      createdBy: createdByMap?['fullName'] as String? ?? 'BOQ Team',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      items: itemsList,
    );
  }
}

class WalletTransactionModel {
  final String id;
  final String type; // DISBURSEMENT | EXPENSE | REIMBURSEMENT | RETURN_TO_ACCOUNTS
  final String status; // PENDING | APPROVED | REJECTED | SETTLED
  final DateTime date;
  final double amount;
  final double charge;
  final double totalAmount;
  final String paymentMethod;
  final String paidFrom; // COMPANY_ADVANCE | PERSONAL_POCKET
  final String category;
  final String particular;
  final String? voucherNo;
  final String? receiptUrl;
  final String? leadId;
  final String? leadName;
  final String? requisitionNo;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.status,
    required this.date,
    required this.amount,
    required this.charge,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paidFrom,
    required this.category,
    required this.particular,
    this.voucherNo,
    this.receiptUrl,
    this.leadId,
    this.leadName,
    this.requisitionNo,
  });

  bool get isExpense => type == 'EXPENSE';
  bool get isDisbursement => type == 'DISBURSEMENT';
  bool get isFromPersonalPocket => paidFrom == 'PERSONAL_POCKET';

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'EXPENSE',
      status: json['status'] as String? ?? 'PENDING',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      charge: (json['charge'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? 'CASH',
      paidFrom: json['paidFrom'] as String? ?? 'COMPANY_ADVANCE',
      category: json['category'] as String? ?? 'RAW_MATERIALS',
      particular: json['particular'] as String? ?? 'Expense',
      voucherNo: json['voucherNo'] as String?,
      receiptUrl: json['receiptUrl'] as String?,
      leadId: json['leadId'] as String?,
      leadName: json['leadName'] as String?,
      requisitionNo: json['requisitionNo'] as String?,
    );
  }
}

class ActiveProjectModel {
  final String id;
  final String name;
  final String? location;

  const ActiveProjectModel({
    required this.id,
    required this.name,
    this.location,
  });

  factory ActiveProjectModel.fromJson(Map<String, dynamic> json) {
    return ActiveProjectModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Project',
      location: json['location'] as String?,
    );
  }
}

class SupplierModel {
  final String id;
  final String supplierCode;
  final String name;
  final String? companyName;
  final String? phone;
  final String? email;
  final String? supplyCategory;
  final String? address;

  const SupplierModel({
    required this.id,
    required this.supplierCode,
    required this.name,
    this.companyName,
    this.phone,
    this.email,
    this.supplyCategory,
    this.address,
  });

  String get displayName =>
      companyName?.isNotEmpty == true ? '$name ($companyName)' : name;

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] as String? ?? '',
      supplierCode: json['supplierCode'] as String? ?? '',
      name: json['name'] as String? ?? '',
      companyName: json['companyName'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      supplyCategory: json['supplyCategory'] as String?,
      address: json['address'] as String?,
    );
  }
}

class ProcurementDashboardData {
  final ProcurementMetrics metrics;
  final ProcurementWalletSummary wallet;
  final List<MaterialRequisitionSummary> recentRequisitions;
  final List<WalletTransactionModel> recentTransactions;

  const ProcurementDashboardData({
    required this.metrics,
    required this.wallet,
    required this.recentRequisitions,
    required this.recentTransactions,
  });

  factory ProcurementDashboardData.fromJson(Map<String, dynamic> json) {
    final metricsMap = json['metrics'] as Map<String, dynamic>? ?? {};
    final walletMap = json['wallet'] as Map<String, dynamic>? ?? {};
    final reqsList = (json['recentRequisitions'] as List<dynamic>?)
            ?.map((e) => MaterialRequisitionSummary.fromJson(
                e as Map<String, dynamic>))
            .toList() ??
        [];
    final txList = (json['recentTransactions'] as List<dynamic>?)
            ?.map((e) => WalletTransactionModel.fromJson(
                e as Map<String, dynamic>))
            .toList() ??
        [];

    return ProcurementDashboardData(
      metrics: ProcurementMetrics.fromJson(metricsMap),
      wallet: ProcurementWalletSummary.fromJson(walletMap),
      recentRequisitions: reqsList,
      recentTransactions: txList,
    );
  }
}

class ProcurementWalletData {
  final ProcurementWalletSummary wallet;
  final List<WalletTransactionModel> transactions;
  final List<ActiveProjectModel> activeProjects;

  const ProcurementWalletData({
    required this.wallet,
    required this.transactions,
    required this.activeProjects,
  });

  factory ProcurementWalletData.fromJson(Map<String, dynamic> json) {
    final walletMap = json['wallet'] as Map<String, dynamic>? ?? {};
    final txList = (json['transactions'] as List<dynamic>?)
            ?.map((e) => WalletTransactionModel.fromJson(
                e as Map<String, dynamic>))
            .toList() ??
        [];
    final projList = (json['activeProjects'] as List<dynamic>?)
            ?.map((e) =>
                ActiveProjectModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ProcurementWalletData(
      wallet: ProcurementWalletSummary.fromJson(walletMap),
      transactions: txList,
      activeProjects: projList,
    );
  }
}
