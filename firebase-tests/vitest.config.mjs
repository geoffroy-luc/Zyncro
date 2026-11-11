import { defineConfig } from 'vitest/config';

// Les fichiers partagent le même émulateur (clearFirestore/clearStorage) :
// exécution séquentielle obligatoire.
export default defineConfig({
  test: {
    fileParallelism: false,
    testTimeout: 20000,
    hookTimeout: 30000,
  },
});
