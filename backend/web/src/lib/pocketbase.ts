import { newApiClient } from 'backend-api'

const pocketbaseUrl = import.meta.env.VITE_POCKETBASE_URL || 'http://127.0.0.1:8090'

export const pb = newApiClient(pocketbaseUrl)

pb.autoCancellation(false)
