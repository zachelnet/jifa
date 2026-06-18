<!--
    Copyright (c) 2023 Contributors to the Eclipse Foundation

    See the NOTICE file(s) distributed with this work for additional
    information regarding copyright ownership.

    This program and the accompanying materials are made available under the
    terms of the Eclipse Public License 2.0 which is available at
    http://www.eclipse.org/legal/epl-2.0

    SPDX-License-Identifier: EPL-2.0
 -->
<script setup lang="ts">
import { BarElement, CategoryScale, Chart, Legend, LinearScale, Title, Tooltip } from 'chart.js';
import { Bar } from 'vue-chartjs';
import { useAnalysisApiRequester } from '@/composables/analysis-api-requester';
import { tdt } from '@/i18n/i18n';
import Thread from '@/components/threaddump/Thread.vue';

Chart.register(BarElement, CategoryScale, LinearScale, Title, Tooltip, Legend);

const { request } = useAnalysisApiRequester();

const loading = ref(false);

interface CpuThread {
  id: number;
  name: string;
  cpu: number | null;
}

const threads = ref<CpuThread[]>([]);
const threadDialogVisible = ref(false);
const selectedThreadId = ref<number | null>(null);

const COLOR_PALETTE = [
  '#003f5c', '#2f4b7c', '#665191', '#a05195', '#d45087',
  '#f95d6a', '#ff7c43', '#ffa600', '#488f31', '#8aa1b4'
];

function determineUnit(maxMs: number): string {
  if (maxMs >= 3_600_000) return 'hours';
  if (maxMs >= 60_000)    return 'minutes';
  if (maxMs >= 1_000)     return 'seconds';
  return 'milliseconds';
}

function toUnit(ms: number, unit: string): number {
  if (unit === 'hours')   return ms / 3_600_000;
  if (unit === 'minutes') return ms / 60_000;
  if (unit === 'seconds') return ms / 1_000;
  return ms;
}

const unit = computed(() => {
  const maxMs = threads.value.reduce((m, t) => Math.max(m, t.cpu ?? 0), 0);
  return determineUnit(maxMs);
});

const chartData = computed(() => ({
  // One dataset per thread so each bar gets its own colour (matching original)
  datasets: threads.value.map((t, i) => ({
    label: t.name,
    backgroundColor: COLOR_PALETTE[i % COLOR_PALETTE.length],
    data: [{ x: t.name, y: parseFloat(toUnit(t.cpu ?? 0, unit.value).toFixed(3)) }]
  })),
  labels: [tdt('cpuConsumingThreads.cpuConsumptionLabel') + ' (' + tdt('cpuConsumingThreads.' + unit.value) + ')']
}));

const chartOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        title: (items: any[]) => items[0]?.dataset?.label ?? '',
        label: (item: any) => ` ${item.parsed.y.toFixed(3)} ${tdt('cpuConsumingThreads.' + unit.value)}`
      }
    }
  },
  onClick: (_e: any, elements: any[]) => {
    if (elements.length) {
      const thread = threads.value[elements[0].datasetIndex];
      if (thread) openThread(thread.id);
    }
  }
}));

function openThread(id: number) {
  selectedThreadId.value = id;
  threadDialogVisible.value = true;
}

onMounted(() => {
  loading.value = true;
  request('cpuConsumingThreads', { max: 10 }).then((data: CpuThread[]) => {
    threads.value = data ?? [];
    loading.value = false;
  });
});
</script>

<template>
  <div v-loading="loading">
    <p style="margin: 0 0 8px; font-weight: 500">{{ tdt('cpuConsumingThreads.title') }}</p>
    <Bar
      v-if="threads.length > 0"
      :data="chartData"
      :options="chartOptions"
      style="height: 360px; cursor: pointer"
    />
    <el-empty v-else :description="'-'" />

    <el-dialog v-model="threadDialogVisible" width="80%" destroy-on-close>
      <Thread :ids="selectedThreadId != null ? [selectedThreadId] : []" />
    </el-dialog>
  </div>
</template>
