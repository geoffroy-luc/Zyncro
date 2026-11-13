import { beforeEach, describe, expect, it, vi } from "vitest";
import { fakeAdmin, reset, store } from "./fakeAdmin";

vi.mock("firebase-admin", () => fakeAdmin);
vi.mock("firebase-admin/firestore", () => ({ FieldValue: fakeAdmin.firestore.FieldValue }));

import { PREVIEWS_PER_HOUR } from "../src/invites/getInvitePreview";
import * as fns from "../src/index";

type Callable = { run: (req: unknown) => Promise<unknown> };
const preview = (uid: string | undefined, data: unknown) =>
  (fns.getInvitePreview as unknown as Callable).run({ auth: uid ? { uid } : undefined, data });

beforeEach(() => {
  reset();
  // Code créé quand l'espace s'appelait « Ancien nom », puis renommé.
  store.set("invite_codes/ABC123", { groupId: "g1", groupName: "Ancien nom", groupEmoji: "🏠" });
  store.set("groups/g1", { name: "Famille Martin", emoji: "🌳", memberIds: ["owner"] });
});

describe("getInvitePreview", () => {
  it("nom et emoji actuels de l'espace, pas la copie du code", async () => {
    expect(await preview("bob", { code: "abc123" })).toEqual({
      groupId: "g1",
      groupName: "Famille Martin",
      groupEmoji: "🌳",
    });
  });

  it("ancien code sans nom : le nom de l'espace est quand même renvoyé", async () => {
    store.set("invite_codes/OLD999", { groupId: "g1" });
    expect(await preview("bob", { code: "OLD999" })).toMatchObject({ groupName: "Famille Martin" });
  });

  it("espace sans emoji : repli sur la copie du code", async () => {
    store.set("groups/g1", { name: "Famille Martin", memberIds: ["owner"] });
    expect(await preview("bob", { code: "ABC123" })).toMatchObject({ groupEmoji: "🏠" });
  });

  it("code inconnu ou espace supprimé → groupId null", async () => {
    const none = { groupId: null, groupName: null, groupEmoji: null };
    expect(await preview("bob", { code: "ZZZ999" })).toEqual(none);
    store.delete("groups/g1");
    expect(await preview("bob", { code: "ABC123" })).toEqual(none);
  });

  it("refus : non connecté, code invalide, trop d'appels", async () => {
    await expect(preview(undefined, { code: "ABC123" })).rejects.toMatchObject({ code: "unauthenticated" });
    await expect(preview("bob", { code: "AB" })).rejects.toMatchObject({ code: "invalid-argument" });
    for (let i = 0; i < PREVIEWS_PER_HOUR; i++) await preview("eve", { code: "ZZZ999" });
    await expect(preview("eve", { code: "ABC123" })).rejects.toMatchObject({ code: "resource-exhausted" });
  });
});
