<!--
    Copyright (c) 2026 Contributors to the Eclipse Foundation

    See the NOTICE file(s) distributed with this work for additional
    information regarding copyright ownership.

    This program and the accompanying materials are made available under the
    terms of the Eclipse Public License 2.0 which is available at
    http://www.eclipse.org/legal/epl-2.0

    SPDX-License-Identifier: EPL-2.0 and CC0-1.0

    AI Disclosure: This file was largely AI-generated with GitHub Copilot.
    The AI-generated portions are made available under CC0-1.0. The human
    contributor has reviewed and verified the code.
    Assisted-by: GitHub Copilot (Claude Sonnet 4.5)
 -->
<script setup lang="ts">
import * as echarts from 'echarts';
import { isDark } from '@/composables/theme';
import { useAnalysisApiRequester } from '@/composables/analysis-api-requester';
import { tdt } from '@/i18n/i18n';
import Thread from '@/components/threaddump/Thread.vue';

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

const chartRef = ref<HTMLElement | null>(null);
let chartInstance: echarts.ECharts | null = null;

const chartHeight = computed(() => Math.max(180, threads.value.length * 40));

function truncate(str: string, n: number): string {
  return str.length > n ? str.slice(0, n - 1) + '…' : str;
}

function openThread(id: number) {
  selectedThreadId.value = id;
  threadDialogVisible.value = true;
}

function render() {
  if (!chartRef.value || threads.value.length === 0) return;
  chartInstance?.dispose();
  chartInstance = echarts.init(chartRef.value, isDark.value ? 'dark' : null);

  const maxMs = threads.value.reduce((m, t) => Math.max(m, t.cpu ?? 0), 0);
  const unitKey = maxMs >= 3_600_000 ? 'hours' : maxMs >= 60_000 ? 'minutes' : maxMs >= 1_000 ? 'seconds' : 'milliseconds';
  const div = unitKey === 'hours' ? 3_600_000 : unitKey === 'minutes' ? 60_000 : unitKey === 'seconds' ? 1_000 : 1;
  const unitLabel = tdt('cpuConsumingThreads.' + unitKey);

  const names = threads.value.map(t => truncate(t.name, 35));
  const values = threads.value.map(t => parseFloat(((t.cpu ?? 0) / div).toFixed(3)));

  chartInstance.setOption({
    color: COLOR_PALETTE,
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
      formatter: (params: any) => `${params[0].name}<br/>${params[0].value} ${unitLabel}`
    },
    grid: { left: 220, right: 20, top: 10, bottom: 40 },
    xAxis: {
      type: 'value',
      name: `${tdt('cpuConsumingThreads.cpuConsumptionLabel')} (${unitLabel})`
    },
    yAxis: {
      type: 'category',
      data: names,
      inverse: true,
      axisLabel: { fontSize: 11, width: 200, overflow: 'truncate' }
    },
    series: [{
      type: 'bar',
      cursor: 'pointer',
      data: values.map((v, i) => ({
        value: v,
        itemStyle: { color: COLOR_PALETTE[i % COLOR_PALETTE.length] }
      }))
    }]
  });

  chartInstance.on('click', (params: any) => {
    const thread = threads.value[params.dataIndex];
    if (thread) openThread(thread.id);
  });
}

function resize() {
  chartInstance?.resize();
}

watch(isDark, () => render());

onMounted(() => {
  window.addEventListener('resize', resize);
  loading.value = true;
  request('cpuConsumingThreads', { max: 10 }).then((data: CpuThread[]) => {
    threads.value = data ?? [];
    loading.value = false;
    nextTick(() => render());
  });
});

onUnmounted(() => {
  window.removeEventListener('resize', resize);
  chartInstance?.dispose();
});
</script>

<template>
  <div v-loading="loading">
    <p style="margin: 0 0 8px; font-weight: 500">{{ tdt('cpuConsumingThreads.title') }}</p>
    <div
      v-if="threads.length > 0"
      ref="chartRef"
      :style="{ height: `${chartHeight}px`, cursor: 'pointer' }"
    />
    <el-empty v-if="!loading && threads.length === 0" :description="'-'" />

    <el-dialog v-model="threadDialogVisible" width="80%" destroy-on-close>
      <Thread :ids="selectedThreadId != null ? [selectedThreadId] : []" />
    </el-dialog>
  </div>
</template>
