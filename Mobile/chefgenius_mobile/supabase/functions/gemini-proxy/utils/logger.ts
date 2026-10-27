export const log = {
    info: (runId: string, message: string, data?: object) => {
        console.info(JSON.stringify({
            level: 'INFO',
            run_id: runId,
            message,
            ...data,
            timestamp: new Date().toISOString()
        }))
    },
    warn: (runId: string, message: string, data?: object) => {
        console.warn(JSON.stringify({
            level: 'WARN',
            run_id: runId,
            message,
            ...data,
            timestamp: new Date().toISOString()
        }))
    },
    error: (runId: string, message: string, error?: unknown, data?: object) => {
        console.error(JSON.stringify({
            level: 'ERROR',
            run_id: runId,
            message,
            error: error instanceof Error ? error.message : (typeof error === 'object' ? JSON.stringify(error) : String(error)),
            ...data,
            timestamp: new Date().toISOString()
        }))
    }
}