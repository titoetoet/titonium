.pragma library

function request(entry) {
    if (!entry || typeof entry.execute !== "function") {
        return { accepted: false, error: "application.error.unavailable", detail: "" };
    }
    try {
        entry.execute();
        return { accepted: true, error: "", detail: "" };
    } catch (error) {
        return { accepted: false, error: "application.error.launch_failed", detail: String(error) };
    }
}
