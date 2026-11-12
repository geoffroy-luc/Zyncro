// Faux firebase-admin minimal pour tester les triggers sans réseau :
// Firestore en mémoire + enregistrement des envois FCM et des suppressions.
type Data = Record<string, unknown>;

export const store = new Map<string, Data>();
export const sent: unknown[] = [];
export const deleted: string[] = [];
export const authUsers = new Map<string, { displayName?: string }>();

export function reset(): void {
  store.clear();
  sent.length = 0;
  deleted.length = 0;
  authUsers.clear();
}

class DocRef {
  constructor(readonly path: string) {}
  get id(): string {
    return this.path.split("/").pop() as string;
  }
  collection(name: string): CollRef {
    return new CollRef(`${this.path}/${name}`);
  }
  async get(): Promise<{ exists: boolean; data: () => Data | undefined }> {
    const data = store.get(this.path);
    return { exists: data !== undefined, data: () => data };
  }
}

let autoId = 0;

/** Sentinelles FieldValue : résolues à l'écriture (comme le serveur). */
const SERVER_TIME = { __fv: "serverTimestamp" } as const;
type ArrayUnion = { __fv: "arrayUnion"; values: unknown[] };

function resolve(current: Data | undefined, patch: Data): Data {
  const out: Data = { ...(current ?? {}) };
  for (const [k, v] of Object.entries(patch)) {
    if (v === SERVER_TIME) {
      out[k] = "SERVER_TIMESTAMP";
    } else if (v && typeof v === "object" && "__fv" in v && v.__fv === "arrayUnion") {
      const prev = Array.isArray(out[k]) ? (out[k] as unknown[]) : [];
      out[k] = [...prev, ...(v as ArrayUnion).values.filter((x) => !prev.includes(x))];
    } else {
      out[k] = v;
    }
  }
  return out;
}

class CollRef {
  constructor(readonly path: string, private readonly max = Infinity) {}
  doc(id?: string): DocRef {
    return new DocRef(`${this.path}/${id ?? `auto${++autoId}`}`);
  }
  limit(n: number): CollRef {
    return new CollRef(this.path, n);
  }
  async get(): Promise<{ empty: boolean; docs: { ref: DocRef }[] }> {
    const prefix = `${this.path}/`;
    const docs = [...store.keys()]
      .filter((k) => k.startsWith(prefix) && !k.slice(prefix.length).includes("/"))
      .sort()
      .slice(0, this.max)
      .map((k) => ({ ref: new DocRef(k) }));
    return { empty: docs.length === 0, docs };
  }
}

const db = {
  doc: (path: string) => new DocRef(path),
  collection: (name: string) => new CollRef(name),
  batch: () => {
    const ops: (() => void)[] = [];
    return {
      delete: (ref: DocRef) =>
        ops.push(() => {
          store.delete(ref.path);
          deleted.push(ref.path);
        }),
      set: (ref: DocRef, data: Data) => ops.push(() => store.set(ref.path, resolve(undefined, data))),
      update: (ref: DocRef, data: Data) =>
        ops.push(() => {
          if (!store.has(ref.path)) throw new Error(`NOT_FOUND ${ref.path}`);
          store.set(ref.path, resolve(store.get(ref.path), data));
        }),
      commit: async () => {
        for (const op of ops) op();
      },
    };
  },
  runTransaction: async <T>(fn: (tx: unknown) => Promise<T>): Promise<T> => {
    const writes: (() => void)[] = [];
    const tx = {
      get: (ref: DocRef) => ref.get(),
      set: (ref: DocRef, data: Data) => writes.push(() => store.set(ref.path, resolve(undefined, data))),
    };
    const result = await fn(tx);
    for (const w of writes) w();
    return result;
  },
};

const firestore = Object.assign(() => db, {
  FieldValue: {
    serverTimestamp: () => SERVER_TIME,
    arrayUnion: (...values: unknown[]): ArrayUnion => ({ __fv: "arrayUnion", values }),
  },
});

export const fakeAdmin = {
  initializeApp: () => undefined,
  firestore,
  messaging: () => ({
    send: async (message: unknown) => {
      sent.push({ kind: "send", message });
      return "id";
    },
    sendEachForMulticast: async (message: unknown) => {
      sent.push({ kind: "multicast", message });
      return { successCount: 0, failureCount: 0, responses: [] };
    },
  }),
  auth: () => ({
    getUser: async (uid: string) => {
      const user = authUsers.get(uid);
      if (!user) throw new Error("auth/user-not-found");
      return user;
    },
  }),
};
