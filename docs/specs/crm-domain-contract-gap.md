# CRM Domain Contract Gap Audit

This document summarizes the contract gap analysis performed as part of Phase 4 of the CRM Domain Expansion planning. 

The audit scanned the codebase in the Flutter frontend (`/lib`) and the Node.js Zalo Bot service (`/integration/zalo-bot-service/src`) to verify the existence of endpoints, data models, or state providers for:
- **Appointments (Lịch hẹn)**
- **Orders (Đơn hàng)**
- **Reports (Báo cáo kinh doanh)**
- **Team ACL / Permission Management (Quản lý phân quyền nhóm)**

---

## 1. Audit Findings

> [!WARNING]
> **Conclusion:** Data contracts and API endpoints for Appointments, Orders, Reports, and Team ACL are completely **missing** from both the cloud API definitions (`CrmCloudApi`) and the local Zalo agent backend. 
> 
> No UI implementation was executed for these domains to avoid creating mock-only, disconnected interfaces.

### Detailed Scope Gaps:
1. **Appointments (Lịch hẹn):**
   - **Backend:** No `/crm/appointments` endpoints found.
   - **Frontend:** No data models (e.g., `Appointment`), providers, or calendar widgets exist in the workspace.
2. **Orders (Đơn hàng):**
   - **Backend:** No `/crm/orders` endpoints found.
   - **Frontend:** No order models or transaction screens.
3. **Reports (Báo cáo kinh doanh):**
   - **Backend:** The only references to "report" relate to Zalo anti-spam report counts (anti-ban thresholds) or "reporting" command execution logs to the cloud. There is no business reporting endpoint.
   - **Frontend:** No analytics widgets or export endpoints beyond basic Customer CSV and Send History logs.
4. **Team ACL (Phân quyền):**
   - **Backend:** No user/team roles or assignment models.
   - **Frontend:** No access-control state or user-management screens.

---

## 2. Proposed API Contract Specifications

To support future integration, the following REST endpoint contracts are proposed for the cloud backend:

### A. Appointments API
- **Endpoint:** `GET /crm/appointments` (list) / `POST /crm/appointments` (create)
- **Response Shape:**
  ```json
  {
    "success": true,
    "data": [
      {
        "_id": "appt_123",
        "customerId": "cust_456",
        "customerName": "Nguyễn Văn A",
        "title": "Tư vấn hợp đồng bảo hiểm",
        "description": "Gặp mặt trực tiếp tại văn phòng",
        "scheduledAt": "2026-06-10T09:00:00.000Z",
        "status": "pending" 
      }
    ]
  }
  ```

### B. Orders API
- **Endpoint:** `GET /crm/orders?customerId=<id>`
- **Response Shape:**
  ```json
  {
    "success": true,
    "data": [
      {
        "_id": "order_789",
        "customerId": "cust_456",
        "items": [
          { "productName": "Gói Bảo hiểm Alpha", "quantity": 1, "price": 5000000 }
        ],
        "totalAmount": 5000000,
        "paymentStatus": "paid",
        "createdAt": "2026-06-03T15:30:00.000Z"
      }
    ]
  }
  ```

### C. Team ACL API
- **Endpoint:** `GET /crm/team/permissions`
- **Response Shape:**
  ```json
  {
    "success": true,
    "data": {
      "userId": "user_abc",
      "role": "agent",
      "permissions": ["customers:read", "customers:write", "campaigns:execute"],
      "assignedCustomerIds": ["cust_456", "cust_789"]
    }
  }
  ```

---

## 3. Recommendations & Next Steps

1. **Defer Domain UI:** Do not proceed with building any UI layout or navigation route for Appointments, Orders, Reports, or Team ACL until the cloud backend implements the endpoints outlined above.
2. **Contact Detail Panel Timeline:** Once the backend contracts are live, implement a "Customer Activity Timeline" inside the Customer Detail Panel in `customers_screen.dart` to combine chat events, orders, and appointment schedules under a unified view.
3. **ACL Enforcement:** Future architectures must verify role-based permissions in GoRouter guards or UI action buttons utilizing the Team ACL permission list.
