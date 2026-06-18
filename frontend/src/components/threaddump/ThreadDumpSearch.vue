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
import { ArcElement, Chart, Legend, Title, Tooltip } from 'chart.js';
import { Doughnut } from 'vue-chartjs';
import { tdt } from '@/i18n/i18n';
import { useAnalysisApiRequester } from '@/composables/analysis-api-requester';
import ThreadDumpSearchForm from './ThreadDumpSearchForm.vue';
import type { SearchModel } from './ThreadDumpSearchForm.vue';
import Thread from './Thread.vue';

Chart.register(ArcElement, Title, Tooltip, Legend);

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

interface SearchHit {
  id: number;
  name: string;
  javaState: string | null;
  osState: string;
  cpu: number;
  elapsed: number;
  lines: string[];
}

const loading = ref(false);
const searched = ref(false);
const currentSearch = ref<SearchModel | null>(null);
const searchResult = ref<SearchHit[]>([]);
const threadDialogVisible = ref(false);
const selectedThreadId = ref<number | null>(null);

// --- chart ---

const stateChartData = computed(() => {
  const counts = new Map<string, number>();
  for (const hit of searchResult.value) {
    const state = hit.javaState ?? hit.osState;
    counts.set(state, (counts.get(state) ?? 0) + 1);
  }
  return {
    labels: [...counts.keys()],
    datasets: [
      {
        data: [...counts.values()],
        backgroundColor: COLOR_PALETTE
      }
    ]
  };
});

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  plugins: { legend: { position: 'bottom' as const } }
};

// --- helpers ---

function getThreadState(hit: SearchHit): string {
  return hit.javaState ?? hit.osState;
}

/** Sanitise and highlight a single content line. */
function renderContent(hit: SearchHit): string {
  const model = currentSearch.value;
  if (!model || !model.term) return '';

  const raw = typeof model.term === 'string' ? model.term.trim() : '';
  const terms = raw.split(/\s+/).filter(Boolean);
  if (!terms.length) return '';

  const patterns = terms.map((t) => {
    const escaped = model.regex ? t : t.replace(/[-[\]{}()*+?.,\\^$|]/g, '\\$&');
    const flags = 'g' + (model.matchCase ? '' : 'i');
    return new RegExp(`(${escaped})`, flags);
  });

  let content = '';
  // skip line 0 (thread header – already shown as card title)
  hit.lines.slice(1).forEach((line) => {
    let modified = line.replace(/</g, '&lt;').replace(/>/g, '&gt;') + '\n';
    patterns.forEach((p) => {
      modified = modified.replaceAll(p, '<span class="search-hit">$1</span>');
    });
    content += modified;
  });
  return content;
}

function openThread(id: number) {
  selectedThreadId.value = id;
  threadDialogVisible.value = true;
}

// --- search ---

async function doSearch(model: SearchModel) {
  searched.value = true;
  loading.value = true;
  currentSearch.value = model;
  searchResult.value = [];

  const terms =
    typeof model.term === 'string'
      ? model.term
          .trim()
          .split(/\s+/)
          .filter((s) => s.length > 0)
      : [];

  try {
    const result = await request('searchThreads', {
      term: terms,
      searchName: model.searchName,
      searchState: model.searchState,
      searchStack: model.searchStack,
      regex: model.regex,
      matchCase: model.matchCase,
      allowedJavaStates: model.allowedJavaStates?.length ? model.allowedJavaStates : undefined
    });
    searchResult.value = result ?? [];
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <div>
    <ThreadDumpSearchForm @submit="doSearch" />

    <div v-loading="loading" style="min-height: 40px">
      <template v-if="searched && !loading">
        <!-- summary row -->
        <el-row v-if="searchResult.length > 0" :gutter="16" style="margin-top: 16px">
          <el-col :span="7">
            <el-card :header="tdt('threadDumpSearch.threadStatesChartTitle')" style="height: 200px">
              <Doughnut :data="stateChartData" :options="chartOptions" style="height: 140px" />
            </el-card>
          </el-col>
          <el-col :span="17" style="display: flex; align-items: center">
            <el-tag type="info" size="large">
              {{ searchResult.length }} {{ tdt('threadDumpSearch.resultsCount') }}
            </el-tag>
          </el-col>
        </el-row>

        <el-empty v-else :description="tdt('threadDumpSearch.noResults')" style="margin-top: 16px" />

        <!-- result cards -->
        <el-card
          v-for="hit in searchResult"
          :key="hit.id"
          class="thread-card"
          style="margin-top: 12px"
        >
          <template #header>
            <el-row :gutter="16" align="middle">
              <el-col :span="16">
                <el-button link type="primary" @click="openThread(hit.id)">
                  {{ hit.name }}
                </el-button>
              </el-col>
              <el-col :span="8" style="text-align: right">
                <el-tag type="info" effect="dark" round size="small">
                  {{ getThreadState(hit) }}
                </el-tag>
              </el-col>
            </el-row>
          </template>
          <pre class="thread-content" v-html="renderContent(hit)" />
        </el-card>
      </template>
    </div>

    <el-dialog v-model="threadDialogVisible" width="70%" top="5vh" destroy-on-close>
      <Thread v-if="selectedThreadId !== null" :ids="[selectedThreadId]" />
    </el-dialog>
  </div>
</template>

<style scoped>
.thread-content {
  margin: 0;
  padding: 10px;
  background-color: #1e1e2e;
  color: #cdd6f4;
  overflow: auto;
  white-space: pre;
  font-size: 0.75rem;
  font-family: monospace;
  border-radius: 4px;
}

:deep(.search-hit) {
  color: #ff0000;
  background-color: #ffffff;
  font-weight: bold;
}
</style>
