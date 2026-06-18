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
import { ArcElement, BarElement, CategoryScale, Chart, Legend, LinearScale, Title, Tooltip } from 'chart.js';
import { Bar, Doughnut } from 'vue-chartjs';
import { useAnalysisApiRequester } from '@/composables/analysis-api-requester';
import { tdt } from '@/i18n/i18n';
import Diagnose from './Diagnose.vue';
import Thread from './Thread.vue';

Chart.register(ArcElement, BarElement, CategoryScale, LinearScale, Title, Tooltip, Legend);

const { request } = useAnalysisApiRequester();

const COLOR_PALETTE = [
  '#003f5c',
  '#2f4b7c',
  '#665191',
  '#a05195',
  '#d45087',
  '#f95d6a',
  '#ff7c43',
  '#ffa600',
  '#488f31',
  '#8aa1b4'
];

// ---- types ----
interface ThreadStat {
  counts: number[];
  states: string[];
  total: number;
  daemon?: number;
}

interface JavaThreadStat extends ThreadStat {
  javaCounts: number[];
}

interface Overview {
  timestamp: string | null;
  vmInfo: string | null;
  jniRefs: number;
  jniWeakRefs: number;
  deadLockCount: number;
  errorCount: number;
  javaStates: string[];
  javaThreadStat: JavaThreadStat;
  threadGroupStat: Record<string, ThreadStat>;
}

interface CpuThread {
  id: number;
  name: string;
  cpu: number | null;
}

// ---- state ----
const overview = ref<Overview | null>(null);
const cpuThreads = ref<CpuThread[]>([]);
const loading = ref(false);

const threadDialogVisible = ref(false);
const selectedThreadId = ref<number | null>(null);

// ---- charts ----

const stateChartData = computed(() => {
  const ov = overview.value;
  if (!ov) return { labels: [], datasets: [] };
  const nonZero: [string, number][] = ov.javaStates
    .map((s, i): [string, number] => [s, ov.javaThreadStat.javaCounts[i]])
    .filter(([, v]) => v > 0);
  return {
    labels: nonZero.map(([s]) => s),
    datasets: [
      {
        data: nonZero.map(([, v]) => v),
        backgroundColor: COLOR_PALETTE
      }
    ]
  };
});

const doughnutOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { position: 'right' as const } }
};

// determine time unit for CPU bar chart
const cpuUnit = computed<string>(() => {
  const maxMs = cpuThreads.value.reduce((m, t) => Math.max(m, t.cpu ?? 0), 0);
  if (maxMs >= 3_600_000) return 'h';
  if (maxMs >= 60_000) return 'min';
  if (maxMs >= 1_000) return 's';
  return 'ms';
});

function convertCpu(ms: number | null, unit: string): number {
  if (ms == null || ms < 0) return 0;
  if (unit === 'h') return ms / 3_600_000;
  if (unit === 'min') return ms / 60_000;
  if (unit === 's') return ms / 1_000;
  return ms;
}

const cpuChartData = computed(() => {
  const unit = cpuUnit.value;
  return {
    labels: cpuThreads.value.map((t) => truncate(t.name, 30)),
    datasets: [
      {
        label: tdt('threadDumpOverview.cpuConsumingDatasetLabel').replace('{unit}', unit),
        data: cpuThreads.value.map((t) => parseFloat(convertCpu(t.cpu, unit).toFixed(3))),
        backgroundColor: COLOR_PALETTE
      }
    ]
  };
});

const barOptions = computed(() => ({
  responsive: true,
  maintainAspectRatio: false,
  indexAxis: 'y' as const,
  plugins: {
    legend: { display: false },
    tooltip: {
      callbacks: {
        label: (ctx: any) =>
          ` ${ctx.parsed.x.toFixed(3)} ${cpuUnit.value}`
      }
    }
  },
  onClick: (_event: any, elements: any[]) => {
    if (elements.length) {
      const thread = cpuThreads.value[elements[0].index];
      if (thread) openThread(thread.id);
    }
  }
}));

// top thread groups
const topGroups = computed<[string, number][]>(() => {
  if (!overview.value) return [];
  return Object.entries(overview.value.threadGroupStat)
    .map(([k, v]): [string, number] => [k, v.total])
    .sort((a, b) => b[1] - a[1])
    .slice(0, 8);
});

const groupChartData = computed(() => ({
  labels: topGroups.value.map(([k]) => truncate(k, 30)),
  datasets: [
    {
      data: topGroups.value.map(([, v]) => v),
      backgroundColor: COLOR_PALETTE
    }
  ]
}));

const groupBarOptions = {
  responsive: true,
  maintainAspectRatio: false,
  indexAxis: 'y' as const,
  plugins: { legend: { display: false } }
};

// ---- helpers ----

function truncate(str: string, n: number): string {
  return str.length > n ? str.slice(0, n - 1) + '…' : str;
}

function openThread(id: number) {
  selectedThreadId.value = id;
  threadDialogVisible.value = true;
}

// ---- load ----

onMounted(async () => {
  loading.value = true;
  try {
    const [ov, cpu] = await Promise.all([
      request('overview'),
      request('cpuConsumingThreads', { max: 10, type: 'JAVA' })
    ]);
    overview.value = ov;
    cpuThreads.value = cpu ?? [];
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div v-loading="loading">
    <template v-if="overview">
      <!-- Diagnosis -->
      <el-card :header="tdt('threadDumpOverview.diagnosisTitle')" style="margin-bottom: 16px">
        <Diagnose />
      </el-card>

      <!-- Charts row: state distribution + CPU -->
      <el-row :gutter="16" style="margin-bottom: 16px">
        <!-- Java Thread State Distribution -->
        <el-col :span="12">
          <el-card :header="tdt('threadDumpOverview.stateDistributionTitle')" style="height: 260px">
            <Doughnut
              :data="stateChartData"
              :options="doughnutOptions"
              style="height: 195px"
            />
          </el-card>
        </el-col>

        <!-- Top CPU Consuming Threads -->
        <el-col :span="12">
          <el-card
            :header="tdt('threadDumpOverview.cpuConsumingTitle')"
            style="height: 260px"
          >
            <Bar
              v-if="cpuThreads.length > 0"
              :data="cpuChartData"
              :options="barOptions"
              style="height: 195px; cursor: pointer"
            />
            <el-empty v-else :description="'-'" style="height: 195px" />
          </el-card>
        </el-col>
      </el-row>

      <!-- Thread Group Summary -->
      <el-card
        v-if="topGroups.length > 0"
        :header="tdt('threadDumpOverview.threadGroupTitle')"
        style="margin-bottom: 16px"
      >
        <Bar
          :data="groupChartData"
          :options="groupBarOptions"
          style="height: 260px"
        />
      </el-card>
    </template>

    <!-- Thread detail dialog -->
    <el-dialog v-model="threadDialogVisible" width="70%" top="5vh" destroy-on-close>
      <Thread v-if="selectedThreadId !== null" :ids="[selectedThreadId]" />
    </el-dialog>
  </div>
</template>
