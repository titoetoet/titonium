.pragma library
// Protected Spotlight vertical slice.

function initial(mode) {
    return {
        mode: mode === "results" ? "results" : "browse",
        query: "",
        categoryId: "all",
        closeRequested: false
    };
}

function withQuery(state, query) {
    const source = state || {};
    const nextQuery = typeof query === "string" ? query : "";
    return {
        mode: nextQuery.trim().length > 0 ? "results" : "browse",
        query: nextQuery,
        categoryId: source.categoryId || "all",
        closeRequested: false
    };
}

function escape(state) {
    const source = state || {};
    if (source.mode === "results") {
        return {
            mode: "browse",
            query: "",
            categoryId: source.categoryId || "all",
            closeRequested: false
        };
    }
    return {
        mode: "browse",
        query: source.query || "",
        categoryId: source.categoryId || "all",
        closeRequested: true
    };
}
