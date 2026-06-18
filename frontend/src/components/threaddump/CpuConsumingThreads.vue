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
import { useAnalysisApiRequester } from '@/composables/analysis-api-requester';
import { tdt } from '@/i18n/i18n';
import Thread from '@/components/threaddump/Thread.vue';

const { request } = useAnalysisApiRequester();

const loading = ref(false);

interface CpuThread {
  id: number;
  name: string;
  cpu: number | null;
  elapsed: number | null;
}

const threads = ref<CpuThread[]>([]);

// Thread detail dialog
const threadDialogVisible = ref(false);
const selectedThreadId = ref<number | null>(null);

/** Format milliseconds into a human-readable string using the largest fitting unit. */
function formatCpu(ms: number | null | undefined): string {
  if (ms == null || ms < 0) return '-';
  if (ms >= 3_600_000) {
    return (ms / 3_600_000).toFixed(2) + ' ' + tdt('cpuConsumingThreads.hours');
  }
  if (ms >= 60_000) {
    return (ms / 60_000).toFixed(2) + ' ' + tdt('cpuConsumingThreads.minutes');
  }
  if (ms >= 1_000) {
    return (ms / 1_000).toFixed(2) + ' ' + tdt('cpuConsumingThreads.seconds');
  }
  return ms.toFixed(2) + ' ' + tdt('cpuConsumingThreads.milliseconds');
}

function openThread(id: number) {
  selectedThreadId.value = id;
  threadDialogVisible.value = true;
}

function loadData() {
  loading.value = true;
  request('cpuConsumingThreads', { max: 10 }).then((data: CpuThread[]) => {
    threads.value = data;
    loading.value = false;
  });
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div v-loading="loading">
    <el-table :data="threads" stripe style="width: 100%">
      <el-table-column :label="tdt('threadNameLabel')">
        <template #default="{ row }">
          <span class="clickable" @click="openThread(row.id)">{{ row.name }}</span>
        </template>
      </el-table-column>
      <el-table-column
        :label="tdt('cpuConsumingThreads.cpuConsumptionLabel')"
        width="200"
      >
        <template #default="{ row }">
          {{ formatCpu(row.cpu) }}
        </template>
      </el-table-column>
    </el-table>

    <el-dialog v-model="threadDialogVisible" width="80%">
      <Thread :ids="selectedThreadId != null ? [selectedThreadId] : []" />
    </el-dialog>
  </div>
</template>
