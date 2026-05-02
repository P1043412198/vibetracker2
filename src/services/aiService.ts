import { GoogleGenAI, Type } from "@google/genai";

const getAI = (apiKey: string) => {
  return new GoogleGenAI({ apiKey });
};

export const analyzeWeek = async (apiKey: string, data: any) => {
  const ai = getAI(apiKey);
  const prompt = `Analyze my week based on the following data and provide actionable insights.
  Data: ${JSON.stringify(data)}
  
  Focus on:
  1. Productivity vs Work Schedule.
  2. Habit consistency.
  3. Workout impact.
  4. Goal progress.
  
  Provide the response in a friendly, encouraging tone. Use Markdown.`;

  const response = await ai.models.generateContent({
    model: "gemini-3-flash-preview",
    contents: prompt,
  });

  return response.text;
};

export const decomposeGoal = async (apiKey: string, goalTitle: string, goalDescription: string) => {
  const ai = getAI(apiKey);
  const prompt = `Decompose the goal "${goalTitle}" (${goalDescription}) into a list of logical, actionable, and specific steps.
  Each step should be a clear task that can be completed.
  Provide between 5 to 10 steps.
  Return the steps as a JSON array of strings.`;

  const response = await ai.models.generateContent({
    model: "gemini-3-flash-preview",
    contents: prompt,
    config: {
      responseMimeType: "application/json",
      responseSchema: {
        type: Type.ARRAY,
        items: {
          type: Type.STRING,
        },
      },
    },
  });

  try {
    return JSON.parse(response.text);
  } catch (e) {
    console.error("Failed to parse AI response", e);
    return [];
  }
};

export const generateWorkout = async (apiKey: string, pastLogs: any, targetMuscleGroups: string[], duration?: number, focus?: string, equipment?: string[]) => {
  const ai = getAI(apiKey);
  const prompt = `Generate a workout plan for today based on past logs, target muscle groups: ${targetMuscleGroups.join(', ')}, duration: ${duration || 60} minutes, focus: ${focus || 'general'}, and available equipment: ${equipment?.join(', ') || 'all'}.
  Past Logs: ${JSON.stringify(pastLogs)}
  
  Return a JSON object with:
  - title: string
  - exercises: array of { name: string, sets: number, reps: string, notes: string }`;

  const response = await ai.models.generateContent({
    model: "gemini-3-flash-preview",
    contents: prompt,
    config: {
      responseMimeType: "application/json",
      responseSchema: {
        type: Type.OBJECT,
        properties: {
          title: { type: Type.STRING },
          exercises: {
            type: Type.ARRAY,
            items: {
              type: Type.OBJECT,
              properties: {
                name: { type: Type.STRING },
                sets: { type: Type.NUMBER },
                reps: { type: Type.STRING },
                notes: { type: Type.STRING },
              },
              required: ["name", "sets", "reps"],
            },
          },
        },
        required: ["title", "exercises"],
      },
    },
  });

  try {
    return JSON.parse(response.text);
  } catch (e) {
    console.error("Failed to parse AI response", e);
    return null;
  }
};
