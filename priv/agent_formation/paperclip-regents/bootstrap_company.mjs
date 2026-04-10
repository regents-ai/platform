const port = Number(process.env.PAPERCLIP_HTTP_PORT || "3100");

const response = await fetch(`http://127.0.0.1:${port}/internal/bootstrap-company`, {
  method: "POST",
  headers: {
    "content-type": "application/json",
  },
  body: JSON.stringify({
    slug: process.env.FORMATION_SLUG,
    public_hostname: process.env.FORMATION_PUBLIC_HOSTNAME,
    stripe_customer_id: process.env.FORMATION_STRIPE_CUSTOMER_ID || null,
    stripe_subscription_id: process.env.FORMATION_STRIPE_SUBSCRIPTION_ID || null,
  }),
});

if (!response.ok) {
  const text = await response.text();
  throw new Error(`Paperclip bootstrap failed: ${response.status} ${text}`);
}

const payload = await response.json();
console.log(JSON.stringify(payload));
