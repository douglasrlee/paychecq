self.addEventListener("install", (event) => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(clients.claim());
});

self.addEventListener("push", async (event) => {
  const data = event.data ? event.data.json() : {};
  const title = data.title || "PayChecQ";
  const options = {
    body: data.body || "You have new activity.",
    icon: "<%= asset_path 'light/logo.png' %>",
    badge: "<%= asset_path 'light/logo.png' %>",
    data: { path: data.path || "/" },
    tag: data.tag || "paychecq-notification",
    renotify: true
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const targetPath = event.notification.data?.path || "/";

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ("focus" in client) {
          client.navigate(targetPath);
          
          return client.focus();
        }
      }

      return clients.openWindow(targetPath);
    })
  );
});
