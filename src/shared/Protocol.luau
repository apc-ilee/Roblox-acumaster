--!strict
export type Phase = "Lobby" | "Intermission" | "Memory" | "Action" | "Recap" | "Victory"
export type Status = "Checking" | "Aiming" | "Placed" | "Missed" | "Timeout" | "Watching"
export type Row = { id: number, name: string, qi: number, alive: boolean, delta: number, ready: boolean, cheers: number }
export type Snapshot = {
 revision: number, phase: Phase, deadline: number, roundStart: number, round: number,
 roundId: string, active: boolean, practice: boolean?, dynamic: boolean, overtime: boolean,
 pool: {string}, clues: {string}, reveal: {string}, step: number, region: string?,
 status: Status, lockUntil: number, rows: {Row}, winner: string?, message: string,
}
export type Intent = { roundId: string, stepIndex: number, hitLocalPosition: Vector3, clientTimestamp: number }

return table.freeze({
 folder = "AcuMasterNetwork", capacity = 12,
 intermission = 10, memory = 10, action = 12, overtime = 5, recap = 5, victory = 7,
})
