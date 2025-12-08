import { createEnv } from '@t3-oss/env-core'
import { z } from 'zod'

export const env = createEnv({
  client: {
    VITE_GIT_SHORT_LINK: z.string(),
  },
  clientPrefix: 'VITE_',
  runtimeEnv: import.meta.env,
})
