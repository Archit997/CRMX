const API_BASE = "/api";

const state = {
  statuses: [],
  clients: [],
  selectedClientId: null,
};

const tabButtons = document.querySelectorAll(".tab-button");
const screens = document.querySelectorAll(".screen");
const form = document.querySelector("#quick-update-form");

function setScreen(screenName) {
  tabButtons.forEach((button) => {
    button.classList.toggle("active", button.dataset.screen === screenName);
  });

  screens.forEach((screen) => {
    screen.classList.toggle("active", screen.id === `screen-${screenName}`);
  });
}

function formatCurrency(value) {
  const number = Number(value || 0);
  if (number >= 100000) return `₹${(number / 100000).toFixed(1)}L`;
  return `₹${number.toLocaleString("en-IN")}`;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

async function api(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(message || `Request failed: ${response.status}`);
  }

  return response.json();
}

async function loadPOC() {
  const [statuses, clients, followups, analytics, finance] = await Promise.all([
    api("/statuses"),
    api("/clients"),
    api("/followups/today"),
    api("/analytics/manager"),
    api("/finance/receivables"),
  ]);

  state.statuses = statuses;
  state.clients = clients;
  state.selectedClientId = state.selectedClientId || clients[0]?.client_id;

  renderSummary(analytics);
  renderSelectors();
  renderFollowups(followups);
  renderClient(await api(`/clients/${state.selectedClientId}`));
  renderManager(analytics);
  renderFinance(finance);
}

function renderSummary(analytics) {
  const summary = analytics.summary;
  document.querySelector("#calls-count").textContent = summary.calls;
  document.querySelector("#whatsapp-count").textContent = summary.whatsapp;
  document.querySelector("#overdue-count").textContent = summary.overdue_followups;
  document.querySelector("#sim-sync-count").textContent = `${summary.calls} calls`;
  document.querySelector("#wa-sync-count").textContent = `${summary.whatsapp} chats`;
}

function renderSelectors() {
  const clientSelect = document.querySelector("#client-select");
  const statusSelect = document.querySelector("#status-select");

  clientSelect.innerHTML = state.clients
    .map(
      (client) =>
        `<option value="${client.client_id}">${escapeHtml(client.client_name)}, ${escapeHtml(client.company_name)}</option>`,
    )
    .join("");
  clientSelect.value = String(state.selectedClientId);

  statusSelect.innerHTML = state.statuses
    .map((status) => `<option value="${status.status_no}">${escapeHtml(status.status_name)}</option>`)
    .join("");

  const current = state.clients.find((client) => client.client_id === state.selectedClientId);
  if (current) statusSelect.value = String(current.current_status_no);
}

function renderFollowups(followups) {
  const list = document.querySelector("#followup-list");
  if (!followups.length) {
    list.innerHTML = `<p class="empty-state">No follow-ups due today.</p>`;
    return;
  }

  list.innerHTML = followups
    .map((item) => {
      const tone = item.is_overdue ? "hot" : item.priority === "Hot" ? "warn" : "cool";
      const time = item.followup_time || "Any time";
      return `
        <article class="task-card ${tone}">
          <div>
            <strong>${escapeHtml(item.client_name)}</strong>
            <p>${escapeHtml(item.note)}</p>
          </div>
          <span>${escapeHtml(time)}</span>
        </article>
      `;
    })
    .join("");
}

function renderClient(client) {
  document.querySelector("#client-company").textContent = client.company_name || "No company";
  document.querySelector("#client-name").textContent = client.client_name;
  document.querySelector("#client-priority").textContent = client.priority;
  document.querySelector("#client-phone").textContent = `+91 ${client.phone}`;
  document.querySelector("#client-owner").textContent = client.assigned_to;
  document.querySelector("#client-need").textContent = client.requirement_summary;
  document.querySelector("#client-city").textContent = client.city || "Not set";

  document.querySelector("#status-rail").innerHTML = state.statuses
    .map((status) => {
      const current = status.status_no === client.current_status_no ? "current" : "";
      return `<button class="${current}" type="button">${status.status_no} ${escapeHtml(status.status_name)}</button>`;
    })
    .join("");

  document.querySelector("#timeline-list").innerHTML = client.updates
    .map(
      (update) => `
        <article>
          <span></span>
          <div>
            <strong>${escapeHtml(update.update_type)}: ${escapeHtml(statusName(update.new_status_no))}</strong>
            <p>${escapeHtml(update.note)}</p>
          </div>
        </article>
      `,
    )
    .join("");
}

function renderManager(analytics) {
  const summary = analytics.summary;
  document.querySelector("#manager-overdue").textContent = summary.overdue_followups;
  document.querySelector("#manager-quoted").textContent = formatCurrency(summary.quoted_value);
  document.querySelector("#manager-payment").textContent = `${summary.payment_pending_clients} payment pending`;
  document.querySelector("#manager-unlogged").textContent = summary.unlogged_calls;
  document.querySelector("#digest-text").textContent =
    `${summary.overdue_followups} overdue follow-ups, ${summary.payment_pending_clients} payment pending clients, ` +
    `${summary.orders_confirmed} order confirmed, ${summary.unlogged_calls} unlogged calls.`;

  document.querySelector("#team-list").innerHTML = analytics.team
    .map(
      (member) => `
        <article>
          <div>
            <strong>${escapeHtml(member.employee)}</strong>
            <p>${member.calls} calls, ${member.unlogged_calls} unlogged</p>
          </div>
          <meter min="0" max="100" value="${member.score}"></meter>
        </article>
      `,
    )
    .join("");
}

function renderFinance(finance) {
  document.querySelector("#finance-total").textContent = `${formatCurrency(finance.total_due)} due`;
  document.querySelector("#finance-message").value = finance.daily_message;

  document.querySelector("#receivable-list").innerHTML = finance.items
    .map(
      (item) => `
        <article>
          <div>
            <strong>${escapeHtml(item.company_name)}</strong>
            <p>${escapeHtml(item.action)}</p>
          </div>
          <span>${formatCurrency(item.amount_due)}</span>
        </article>
      `,
    )
    .join("");
}

function statusName(statusNo) {
  return state.statuses.find((status) => status.status_no === statusNo)?.status_name || `Status ${statusNo}`;
}

function requestTypeFromSubtype(subtype) {
  if (subtype === "None") return "None";
  if (["Quotation", "Receipt", "Delivery"].includes(subtype)) return "Document";
  return "Information";
}

tabButtons.forEach((button) => {
  button.addEventListener("click", () => setScreen(button.dataset.screen));
});

document.querySelector("#client-select").addEventListener("change", async (event) => {
  state.selectedClientId = Number(event.target.value);
  const client = await api(`/clients/${state.selectedClientId}`);
  renderClient(client);
  renderSelectors();
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const clientId = Number(document.querySelector("#client-select").value);
  const requestSubtype = document.querySelector("#request-select").value;
  const payload = {
    update_type: requestSubtype === "None" ? "Call" : "Follow-up",
    new_status_no: Number(document.querySelector("#status-select").value),
    request_type: requestTypeFromSubtype(requestSubtype),
    request_subtype: requestSubtype,
    note: document.querySelector("#note-input").value.trim(),
    followup_date: document.querySelector("#follow-date").value,
    followup_time: document.querySelector("#follow-time").value,
    created_by: "Mobile POC",
  };

  if (!payload.note) return;

  await api(`/clients/${clientId}/updates`, {
    method: "POST",
    body: JSON.stringify(payload),
  });

  state.selectedClientId = clientId;
  await loadPOC();
  setScreen("client");
});

loadPOC().catch((error) => {
  console.error(error);
  document.querySelector("#followup-list").innerHTML =
    `<p class="empty-state">Backend API is not reachable. Start FastAPI and open /mobile/index.html.</p>`;
});
