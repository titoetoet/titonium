.pragma library
// Protected Spotlight vertical slice.

function tokenize(expression) {
    const tokens = [];
    let index = 0;
    while (index < expression.length) {
        const character = expression[index];
        if (/\s/.test(character)) {
            index++;
            continue;
        }
        if (/[0-9.]/.test(character)) {
            const start = index;
            let dotCount = 0;
            while (index < expression.length && /[0-9.]/.test(expression[index])) {
                if (expression[index] === ".")
                    dotCount++;
                index++;
            }
            const literal = expression.slice(start, index);
            if (dotCount > 1 || literal === ".")
                return null;
            tokens.push({ type: "number", value: Number(literal) });
            continue;
        }
        if (/[A-Za-z]/.test(character)) {
            const start = index;
            while (index < expression.length && /[A-Za-z]/.test(expression[index]))
                index++;
            tokens.push({ type: "name", value: expression.slice(start, index).toLocaleLowerCase() });
            continue;
        }
        if ("+-*/%^()".indexOf(character) !== -1) {
            tokens.push({ type: character, value: character });
            index++;
            continue;
        }
        return null;
    }
    return tokens;
}

function evaluate(expression) {
    if (typeof expression !== "string" || expression.trim().length === 0)
        return { matched: false };
    const tokens = tokenize(expression);
    if (!tokens || tokens.length === 0)
        return { matched: false };

    let index = 0;
    function peek() {
        return tokens[index];
    }
    function consume(type) {
        if (!peek() || peek().type !== type)
            return false;
        index++;
        return true;
    }
    function parseExpression() {
        let value = parseTerm();
        while (peek() && (peek().type === "+" || peek().type === "-")) {
            const operator = peek().type;
            index++;
            const right = parseTerm();
            value = operator === "+" ? value + right : value - right;
        }
        return value;
    }
    function parseTerm() {
        let value = parseUnary();
        while (peek() && (peek().type === "*" || peek().type === "/" || peek().type === "%")) {
            const operator = peek().type;
            index++;
            const right = parseUnary();
            if (operator === "*")
                value *= right;
            else if (operator === "/")
                value /= right;
            else
                value %= right;
        }
        return value;
    }
    function parseUnary() {
        if (consume("+"))
            return parseUnary();
        if (consume("-"))
            return -parseUnary();
        return parsePower();
    }
    function parsePower() {
        let value = parsePrimary();
        if (consume("^"))
            value = Math.pow(value, parseUnary());
        return value;
    }
    function parsePrimary() {
        const token = peek();
        if (!token)
            throw new Error("missing primary expression");
        if (token.type === "number") {
            index++;
            return token.value;
        }
        if (token.type === "name") {
            index++;
            if (token.value === "pi")
                return Math.PI;
            if ((token.value === "sqrt" || token.value === "sin" || token.value === "cos") && consume("(")) {
                const argument = parseExpression();
                if (!consume(")"))
                    throw new Error("missing closing parenthesis");
                if (token.value === "sqrt")
                    return Math.sqrt(argument);
                return token.value === "sin" ? Math.sin(argument) : Math.cos(argument);
            }
            throw new Error("unknown identifier");
        }
        if (consume("(")) {
            const value = parseExpression();
            if (!consume(")"))
                throw new Error("missing closing parenthesis");
            return value;
        }
        throw new Error("invalid primary expression");
    }

    try {
        const value = parseExpression();
        if (index !== tokens.length || !isFinite(value))
            return { matched: false };
        return { matched: true, value: String(Object.is(value, -0) ? 0 : value) };
    } catch (error) {
        return { matched: false };
    }
}
