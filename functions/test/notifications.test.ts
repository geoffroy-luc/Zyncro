import { describe, expect, it } from "vitest";
import { firstAddedReaction, newMessageBody } from "../src/notifications/messages";
import { asReactions, asString, asStringArray } from "../src/shared/guards";

describe("newMessageBody", () => {
  it("libellés par type", () => {
    expect(newMessageBody("audio", "Al", "")).toBe("Al a envoyé un message vocal 🎤");
    expect(newMessageBody("poll", "Al", "")).toBe("Al a créé un sondage 📊");
    expect(newMessageBody("image", "Al", "")).toBe("Al a envoyé une photo 📷");
    expect(newMessageBody("file", "Al", "")).toBe("Al a envoyé une vidéo 🎥");
  });
  it("texte : aperçu tronqué à 80 caractères", () => {
    expect(newMessageBody("text", "Al", "court")).toBe("Al: court");
    expect(newMessageBody("text", "Al", "x".repeat(80))).toBe(`Al: ${"x".repeat(80)}`);
    expect(newMessageBody("text", "Al", "x".repeat(81))).toBe(`Al: ${"x".repeat(80)}…`);
    expect(newMessageBody(undefined, "Al", "y")).toBe("Al: y");
  });
});

describe("firstAddedReaction", () => {
  it("détecte le premier emoji avec un nouvel uid", () => {
    expect(firstAddedReaction({ a: ["u1"] }, { a: ["u1"], b: ["u2"] })).toEqual({ emoji: "b", reactorUid: "u2" });
  });
  it("aucun ajout (retrait ou identique)", () => {
    expect(firstAddedReaction({ a: ["u1"] }, {})).toBeNull();
    expect(firstAddedReaction({ a: ["u1"] }, { a: ["u1"] })).toBeNull();
  });
});

describe("guards", () => {
  it("asString / asStringArray / asReactions", () => {
    expect(asString("x")).toBe("x");
    expect(asString(3)).toBeUndefined();
    expect(asStringArray(["a", 1, "b"])).toEqual(["a", "b"]);
    expect(asStringArray("nope")).toEqual([]);
    expect(asReactions({ "👍": ["a", 2] })).toEqual({ "👍": ["a"] });
    expect(asReactions(null)).toEqual({});
  });
});
