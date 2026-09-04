.pragma library

var THRESHOLD = 80;
var COOLDOWN_MS = 180;

function update(delta, timestamp, currentPage, pageCount, lastConsumedAt, accumulator) {
    const now = Math.max(0, Number(timestamp) || 0);
    const current = Math.max(0, Math.floor(Number(currentPage) || 0));
    const count = Math.max(0, Math.floor(Number(pageCount) || 0));
    const last = Math.max(0, Number(lastConsumedAt) || 0);
    let sum = Number(accumulator) || 0;
    const movement = Number(delta) || 0;
    if (last > 0 && now - last < COOLDOWN_MS)
        return Object.freeze({ page: current, consumed: false, accumulator: 0,
            lastConsumedAt: last });
    if (sum !== 0 && movement !== 0 && Math.sign(sum) !== Math.sign(movement))
        sum = 0;
    sum += movement;
    if (Math.abs(sum) < THRESHOLD || count < 1)
        return Object.freeze({ page: current, consumed: false, accumulator: sum,
            lastConsumedAt: last });
    const requested = current + (sum < 0 ? 1 : -1);
    const page = Math.max(0, Math.min(count - 1, requested));
    return Object.freeze({ page: page, consumed: page !== current, accumulator: 0,
        lastConsumedAt: page !== current ? now : last });
}
