import { Dialog } from 'quasar'

export function confirm(message: string, okLabel = 'Continuer', okColor = 'primary') {
  return new Promise<boolean>((resolve) => {
    Dialog.create({
      message,
      persistent: true,
      cancel: { label: 'Annuler', flat: true, noCaps: true },
      ok: { label: okLabel, color: okColor, unelevated: true, noCaps: true },
    })
      .onOk(() => resolve(true))
      .onCancel(() => resolve(false))
  })
}
