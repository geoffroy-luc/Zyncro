// S3 phase 1 : adhésion par code côté serveur.
import { beforeEach, describe, expect, it, vi } from "vitest";
import { fakeAdmin, reset, store } from "./fakeAdmin";

vi.mock("firebase-admin", () => fakeAdmin);
vi.mock("firebase-admin/firestore", () => ({ FieldValue: fakeAdmin.firestore.FieldValue }));

import { JOIN_ATTEMPTS_PER_HOUR } from "../src/invites/joinGroupByCode";
import * as fns from "../src/index";

type Callable = { run: (req: unknown) => Promise<{ groupId: string | null; alreadyMember: boolean }> };
const join = (uid: string | undefined, data: unknown) =>
  (fns.joinGroupByCode as unknown as Callable).run({ auth: uid ? { uid } : undefined, data });

beforeEach(() => {
  reset();
  store.set("invite_codes/ABC123", { groupId: "g1", groupName: "Famille" });
  store.set("groups/g1", { name: "Famille", memberIds: ["owner"] });
  store.set("groups/g1/members/owner", { uid: "owner", role: "owner", displayName: "Chef" });
});

const messages = () => [...store.entries()].filter(([k]) => k.startsWith("groups/g1/messages/"));

describe("joinGroupByCode", () => {
  it("ajoute le membre, son document et le message d'arrivée", async () => {
    const r = await join("bob", { code: "abc123", displayName: " Bob ", photoUrl: "https://p", showProfilePhoto: true });
    expect(r).toEqual({ groupId: "g1", alreadyMember: false });
    expect(store.get("groups/g1")?.memberIds).toEqual(["owner", "bob"]);
    expect(store.get("groups/g1/members/bob")).toEqual({
      uid: "bob",
      displayName: "Bob",
      role: "member",
      joinedAt: "SERVER_TIMESTAMP",
      photoUrl: "https://p",
      showProfilePhoto: true,
    });
    expect(messages().map(([, m]) => m)).toEqual([
      {
        groupId: "g1",
        senderId: "bob",
        senderName: null,
        content: "👋 Bob a rejoint le groupe",
        type: "system",
        timestamp: "SERVER_TIMESTAMP",
        notifScreen: "chat",
      },
    ]);
  });

  it("déjà membre : rien n'est écrit, rôle et pseudo conservés (G5)", async () => {
    const r = await join("owner", { code: "ABC123", displayName: "Autre" });
    expect(r).toEqual({ groupId: "g1", alreadyMember: true });
    expect(store.get("groups/g1/members/owner")?.role).toBe("owner");
    expect(messages()).toHaveLength(0);
  });

  it("code inconnu ou espace supprimé → groupId null", async () => {
    expect(await join("bob", { code: "ZZZ999", displayName: "Bob" })).toEqual({ groupId: null, alreadyMember: false });
    store.delete("groups/g1");
    expect(await join("bob", { code: "ABC123", displayName: "Bob" })).toEqual({ groupId: null, alreadyMember: false });
  });

  it("photo masquée : photoUrl non enregistrée", async () => {
    await join("bob", { code: "ABC123", displayName: "Bob", photoUrl: "https://p", showProfilePhoto: false });
    expect(store.get("groups/g1/members/bob")?.photoUrl).toBeNull();
  });

  it("refus : non connecté, code ou pseudo invalide", async () => {
    await expect(join(undefined, { code: "ABC123", displayName: "Bob" })).rejects.toMatchObject({ code: "unauthenticated" });
    await expect(join("bob", { code: "AB", displayName: "Bob" })).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(join("bob", { code: "ABC123", displayName: "" })).rejects.toMatchObject({ code: "invalid-argument" });
    await expect(join("bob", null)).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("limitation de débit par compte", async () => {
    for (let i = 0; i < JOIN_ATTEMPTS_PER_HOUR; i++) {
      await join("eve", { code: "ZZZ999", displayName: "Eve" });
    }
    await expect(join("eve", { code: "ABC123", displayName: "Eve" })).rejects.toMatchObject({ code: "resource-exhausted" });
  });
});
