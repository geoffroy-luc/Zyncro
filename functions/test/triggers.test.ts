// Caractérisation des triggers : notifications FCM exactes (snapshots) et
// suppressions, pour chaque export. Toute modification de structure des
// functions doit laisser ces snapshots inchangés (comportement identique).
import { beforeEach, describe, expect, it, vi } from "vitest";
import { authUsers, deleted, fakeAdmin, reset, sent, store } from "./fakeAdmin";

vi.mock("firebase-admin", () => fakeAdmin);

// Import APRÈS le mock (vi.mock est hissé en tête de fichier).
import * as fns from "../src/index";

type Handler = { run: (event: unknown) => Promise<unknown> };
const run = (fn: unknown, event: unknown) => (fn as Handler).run(event);

const created = (params: Record<string, string>, data: unknown) => ({
  params,
  data: data === undefined ? undefined : { data: () => data },
});
const updated = (params: Record<string, string>, before: unknown, after: unknown) => ({
  params,
  data: { before: { data: () => before }, after: { data: () => after } },
});

function seed(): void {
  store.set("groups/g1", { name: "Famille", memberIds: ["alice", "bob", "carol"] });
  store.set("users/alice", { fcmToken: "tok-alice" });
  store.set("users/bob", { fcmToken: "tok-bob" });
  store.set("users/carol", {});
  store.set("groups/g1/members/alice", { displayName: "Alice" });
  store.set("groups/g1/members/bob", { displayName: "Bob" });
  authUsers.set("carol", { displayName: "Carol (Auth)" });
}

beforeEach(() => {
  reset();
  seed();
});

describe("onNewMessage", () => {
  const msg = (extra: Record<string, unknown>) =>
    created({ groupId: "g1", messageId: "m1" }, { senderId: "alice", senderName: "Alice", ...extra });

  it.each([
    ["texte court", { type: "text", content: "Salut !" }],
    ["texte long tronqué à 80", { type: "text", content: "x".repeat(120) }],
    ["audio", { type: "audio", content: "{}" }],
    ["sondage", { type: "poll", content: "{}" }],
    ["image", { type: "image", content: "{}" }],
    ["vidéo (file)", { type: "file", content: "{}" }],
    ["sans senderName", { type: "text", content: "hey", senderName: undefined }],
  ])("%s", async (_label, extra) => {
    await run(fns.onNewMessage, msg(extra));
    expect(sent).toMatchSnapshot();
  });

  it("message système : aucune notification", async () => {
    await run(fns.onNewMessage, msg({ type: "system", content: "x" }));
    expect(sent).toEqual([]);
  });

  it("aucun destinataire avec token : aucune notification", async () => {
    store.set("users/bob", {});
    await run(fns.onNewMessage, msg({ type: "text", content: "x" }));
    expect(sent).toEqual([]);
  });
});

describe("onMessageReaction", () => {
  const p = { groupId: "g1", messageId: "m1" };
  it("nouvelle réaction d'un autre membre → notifie l'auteur", async () => {
    await run(
      fns.onMessageReaction,
      updated(p, { senderId: "alice", reactions: {} }, { senderId: "alice", reactions: { "❤️": ["bob"] } }),
    );
    expect(sent).toMatchSnapshot();
  });
  it("réaction à son propre message : rien", async () => {
    await run(
      fns.onMessageReaction,
      updated(p, { senderId: "alice" }, { senderId: "alice", reactions: { "👍": ["alice"] } }),
    );
    expect(sent).toEqual([]);
  });
  it("retrait de réaction : rien", async () => {
    await run(
      fns.onMessageReaction,
      updated(p, { senderId: "alice", reactions: { "👍": ["bob"] } }, { senderId: "alice", reactions: {} }),
    );
    expect(sent).toEqual([]);
  });
});

describe("dépenses", () => {
  it("onNewExpense : participants sauf payeur", async () => {
    await run(
      fns.onNewExpense,
      created({ groupId: "g1", expenseId: "x1" }, { paidBy: "alice", paidByName: "Alice", splitWith: ["alice", "bob"] }),
    );
    expect(sent).toMatchSnapshot();
  });
  it("onNewExpense : payeur seul → rien", async () => {
    await run(fns.onNewExpense, created({ groupId: "g1", expenseId: "x1" }, { paidBy: "alice", splitWith: ["alice"] }));
    expect(sent).toEqual([]);
  });
  it("onExpenseUpdated avec updatedBy (pseudo du membre)", async () => {
    const d = { paidBy: "alice", paidByName: "Alice", splitWith: ["alice", "bob"], updatedBy: "bob" };
    await run(fns.onExpenseUpdated, updated({ groupId: "g1", expenseId: "x1" }, d, d));
    expect(sent).toMatchSnapshot();
  });
  it("onExpenseUpdated sans updatedBy (paidByName)", async () => {
    const d = { paidBy: "alice", paidByName: "Alice", splitWith: ["alice", "bob"] };
    await run(fns.onExpenseUpdated, updated({ groupId: "g1", expenseId: "x1" }, d, d));
    expect(sent).toMatchSnapshot();
  });
});

describe("événements", () => {
  const p = { groupId: "g1", eventId: "e1" };
  it("onEventCreated avec creatorName", async () => {
    await run(fns.onEventCreated, created(p, { createdBy: "alice", creatorName: "Ali" }));
    expect(sent).toMatchSnapshot();
  });
  it("onEventCreated sans creatorName (pseudo, repli Auth)", async () => {
    await run(fns.onEventCreated, created(p, { createdBy: "carol" }));
    expect(sent).toMatchSnapshot();
  });
  it("onEventUpdated", async () => {
    const d = { createdBy: "alice", updatedBy: "bob", title: "A" };
    await run(fns.onEventUpdated, updated(p, d, { ...d, title: "B" }));
    expect(sent).toMatchSnapshot();
  });
  it("BUG F2 corrigé : onEventUpdated sans changement réel → rien", async () => {
    const d = { createdBy: "alice", updatedBy: "bob", title: "A" };
    await run(fns.onEventUpdated, updated(p, d, { ...d, updatedBy: "alice" }));
    expect(sent).toEqual([]);
  });
  it("onEventDeleted sans auteur connu (attribué au créateur)", async () => {
    await run(fns.onEventDeleted, created(p, { createdBy: "alice" }));
    expect(sent).toMatchSnapshot();
  });
  it("BUG F1 corrigé : onEventDeleted attribué à l'auteur, non notifié", async () => {
    await run(fns.onEventDeleted, {
      ...created(p, { createdBy: "alice" }),
      authType: "unknown",
      authId: "bob",
    });
    expect(sent).toHaveLength(1);
    expect(JSON.stringify(sent)).toContain("Bob a supprimé un événement");
    expect(JSON.stringify(sent)).not.toContain("tok-bob");
    expect(JSON.stringify(sent)).toContain("tok-alice");
  });
});

describe("notes", () => {
  const p = { groupId: "g1", noteId: "n1" };
  it("onNoteCreated", async () => {
    await run(fns.onNoteCreated, created(p, { createdBy: "bob" }));
    expect(sent).toMatchSnapshot();
  });
  it("onNoteUpdated : contenu modifié", async () => {
    await run(
      fns.onNoteUpdated,
      updated(p, { title: "a", content: "x", createdBy: "bob" }, { title: "b", content: "x", createdBy: "bob", updatedBy: "alice" }),
    );
    expect(sent).toMatchSnapshot();
  });
  it("onNoteUpdated : checklist seule → rien", async () => {
    await run(
      fns.onNoteUpdated,
      updated(p, { title: "a", content: "", checklist: [] }, { title: "a", content: "", checklist: [{ text: "x", done: true }] }),
    );
    expect(sent).toEqual([]);
  });
  it("onNoteDeleted", async () => {
    await run(fns.onNoteDeleted, created(p, { createdBy: "bob" }));
    expect(sent).toMatchSnapshot();
  });
});

describe("groupes", () => {
  it("onGroupDeleted : notifie tous les membres puis purge les sous-collections", async () => {
    store.delete("groups/g1");
    for (const sub of ["members/x", "messages/m1", "messages/m2", "notes/n1", "expenses/x1", "events/e1", "typing/t1", "config/tabSettings"]) {
      store.set(`groups/g1/${sub}`, {});
    }
    await run(
      fns.onGroupDeleted,
      created({ groupId: "g1" }, { name: "Famille", memberIds: ["alice", "bob", "carol"] }),
    );
    expect(sent).toMatchSnapshot();
    expect([...deleted].sort()).toMatchSnapshot();
    expect(store.has("groups/g1/config/tabSettings")).toBe(true); // non purgé (BUGS_FOUND G7)
  });
  it("onMemberRemoved", async () => {
    await run(fns.onMemberRemoved, created({ groupId: "g1", userId: "bob" }, {}));
    expect(sent).toMatchSnapshot();
  });
  it("BUG G8 corrigé : quitter soi-même le groupe → rien", async () => {
    await run(fns.onMemberRemoved, {
      ...created({ groupId: "g1", userId: "bob" }, {}),
      authType: "unknown",
      authId: "bob",
    });
    expect(sent).toEqual([]);
  });
  it("retiré par un autre membre → notifié", async () => {
    await run(fns.onMemberRemoved, {
      ...created({ groupId: "g1", userId: "bob" }, {}),
      authType: "unknown",
      authId: "alice",
    });
    expect(sent).toHaveLength(1);
  });
  it("BUG G7 corrigé : purge après suppression du groupe → rien", async () => {
    store.delete("groups/g1");
    await run(fns.onMemberRemoved, {
      ...created({ groupId: "g1", userId: "bob" }, {}),
      authType: "service_account",
    });
    expect(sent).toEqual([]);
  });
  it("onMemberRemoved : membre sans token → rien", async () => {
    await run(fns.onMemberRemoved, created({ groupId: "g1", userId: "carol" }, {}));
    expect(sent).toEqual([]);
  });
});
