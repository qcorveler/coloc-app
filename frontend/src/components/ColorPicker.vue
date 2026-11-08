<script setup lang="ts">
const color = defineModel<string>({ required: true })

const props = defineProps<{
  takenColors?: string[]
}>()

function colorRule(value: string | null | undefined) {
  if (!value) return 'Choisis une couleur'
  const normalized = value.toLowerCase()
  if (props.takenColors?.some((taken) => taken.toLowerCase() === normalized)) {
    return 'Cette couleur est déjà prise'
  }
  return true
}
</script>

<template>
  <div>
    <q-field :model-value="color" label="Couleur" outlined stack-label :rules="[colorRule]">
      <template #control>
        <div class="row items-center no-wrap q-gutter-sm full-width">
          <input v-model="color" class="color-input" type="color" aria-label="Choisir une couleur" />
          <span class="color-code">{{ color }}</span>
        </div>
      </template>
    </q-field>
    <div v-if="takenColors?.length" class="row items-center q-gutter-xs q-mt-sm">
      <span class="muted">Déjà prises</span>
      <span
        v-for="swatch in takenColors"
        :key="swatch"
        class="color-dot"
        :style="{ background: swatch }"
        :title="swatch"
      />
    </div>
  </div>
</template>
