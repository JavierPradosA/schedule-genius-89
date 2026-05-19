import { createSupabaseClient } from '@/lib/supabaseClient';

export interface FeedbackRatings {
  facilidadUso: number;
  utilidadPercibida: number;
  recomendacion: number;
}

export interface FeedbackPayload extends FeedbackRatings {
  idSesion: string;
}

const FEEDBACK_TABLE = 'feedback_final';

export function getAnonymousSessionId(): string {
  const storageKey = 'optimaus.sessionId';
  const existing = window.sessionStorage.getItem(storageKey);

  if (existing) {
    return existing;
  }

  const id = crypto.randomUUID();
  window.sessionStorage.setItem(storageKey, id);
  return id;
}

export async function saveFeedback(payload: FeedbackPayload): Promise<void> {
  const supabase = await createSupabaseClient();

  if (!supabase) {
    throw new Error('Supabase no está configurado.');
  }

  const { error } = await supabase
    .from(FEEDBACK_TABLE)
    .insert({
      id_sesion: payload.idSesion,
      facilidad_uso: payload.facilidadUso,
      utilidad_percibida: payload.utilidadPercibida,
      recomendacion: payload.recomendacion,
    });

  if (error) {
    throw new Error(error.message);
  }
}
