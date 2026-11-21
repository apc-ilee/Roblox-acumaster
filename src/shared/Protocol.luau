--!strict
export type Phase = "Lobby" | "Intermission" | "Memory" | "Action" | "Recap" | "Victory"
export type Status = "Checking" | "Aiming" | "Placed" | "Missed" | "Timeout" | "Watching"
export type Row = { id: number, name: string, qi: number, alive: boolean, delta: number, ready: boolean, cheers: number }
export type RankRow = { id: number, name: string, points: number }
export type Chart = { period: string, rows: {RankRow}, status: "Loading" | "Ready" | "Unavailable" }
export type Rankings = { daily: Chart, monthly: Chart, saving: boolean, studio: boolean }
export type Snapshot = {
 revision: number, phase: Phase, deadline: number, roundStart: number, round: number,
 roundId: string, active: boolean, practice: boolean?, dynamic: boolean, overtime: boolean,
 pool: {string}, clues: {string}, reveal: {string}, step: number, region: string?,
 study: {ready: number, required: number, voted: boolean}?,
 rankings: Rankings?, matchPoints: number?,
 status: Status, lockUntil: number, rows: {Row}, winner: string?, message: string,
}
export type Intent = { roundId: string, stepIndex: number, hitLocalPosition: Vector3, clientTimestamp: number }

return table.freeze({
 folder = "AcuMasterNetwork", capacity = 12,
 intermission = 10, memory = 10, action = 10, recap = 5, victory = 10,
})
