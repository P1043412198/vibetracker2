import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'ai.vibesight.tracker',
  appName: 'Vibesight Tracker',
  webDir: 'dist',
  android: {
    allowMixedContent: false,
  },
};

export default config;
