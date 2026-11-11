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

class CollRef {
  constructor(readonly path: string, private readonly max = Infinity) {}
  doc(id: string): DocRef {
    return new DocRef(`${this.path}/${id}`);
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
    const ops: DocRef[] = [];
    return {
      delete: (ref: DocRef) => ops.push(ref),
      commit: async () => {
        for (const ref of ops) {
          store.delete(ref.path);
          deleted.push(ref.path);
        }
      },
    };
  },
};

export const fakeAdmin = {
  initializeApp: () => undefined,
  firestore: () => db,
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
