import { describe, expect, it } from "vitest";
import { Subject } from "@/data/demoData";
import { generateSchedules } from "@/lib/scheduleGenerator";

const makeSubject = (
  id: string,
  groups: Subject["groups"],
): Subject => ({
  id,
  name: `Asignatura ${id}`,
  code: id.toUpperCase(),
  credits: 6,
  course: 1,
  semester: "C1",
  type: "obligatoria",
  groups,
});

describe("generateSchedules", () => {
  it("keeps subjects without groups as selection-only options", () => {
    const result = generateSchedules([makeSubject("empty", [])], []);

    expect(result.options[0]).toEqual(
      expect.objectContaining({
        id: "selection-only",
        sessions: [],
        subjects: [
          expect.objectContaining({
            subjectId: "empty",
            groupName: "Horario pendiente",
            professor: "Profesorado pendiente",
          }),
        ],
      }),
    );
    expect(result.warnings).toEqual([
      expect.objectContaining({
        type: "no_groups",
        subjectId: "empty",
      }),
    ]);
  });

  it("prefers groups that avoid blocked time", () => {
    const subject = makeSubject("math", [
      {
        id: "math-morning",
        name: "Mañana",
        professor: "Prof. A",
        type: "theory",
        sessions: [{ day: 0, startHour: 8, endHour: 10 }],
      },
      {
        id: "math-late",
        name: "Tarde",
        professor: "Prof. B",
        type: "theory",
        sessions: [{ day: 0, startHour: 17, endHour: 19 }],
      },
    ]);

    const result = generateSchedules([subject], [
      { day: 0, startHour: 8, endHour: 10 },
    ]);

    expect(result.options[0].blockedViolations).toBe(0);
    expect(result.options[0].selections).toContainEqual({
      subjectId: "math",
      groupId: "math-late",
    });
  });

  it("penalizes professor preference mismatches", () => {
    const subject = makeSubject("ai", [
      {
        id: "ai-a",
        name: "Grupo A",
        professor: "Prof. A",
        type: "theory",
        sessions: [{ day: 0, startHour: 8, endHour: 10 }],
      },
      {
        id: "ai-b",
        name: "Grupo B",
        professor: "Prof. B",
        type: "theory",
        sessions: [{ day: 1, startHour: 8, endHour: 10 }],
      },
    ]);

    const result = generateSchedules([subject], [], { ai: "Prof. B" });

    expect(result.options[0].selections).toContainEqual({
      subjectId: "ai",
      groupId: "ai-b",
    });
  });
});
