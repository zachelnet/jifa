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
import { useI18n } from 'vue-i18n';

const { request } = useAnalysisApiRequester();
const { t } = useI18n();

const loading = ref(false);

interface DiagnosticEntry {
  severity: 'OK' | 'INFO' | 'WARNING' | 'ERROR';
  type: string;
  params: Record<string, any>;
  threads?: { id: number; name: string }[];
  file?: string;
}

const diagnostics = ref<DiagnosticEntry[]>([]);

// Dialog for examining affected threads
const threadDialogVisible = ref(false);
const selectedThreadIds = ref<number[]>([]);

function loadData() {
  loading.value = true;
  diagnostics.value = [];
  request('analyze', {}).then((data: DiagnosticEntry[]) => {
    if (!data || data.length === 0) {
      diagnostics.value = [{ severity: 'OK', type: 'NO_ISSUES', params: {} }];
    } else {
      diagnostics.value = data;
    }
    loading.value = false;
  });
}

function severityColor(severity: string): string {
  if (severity === 'ERROR')   return 'color: #F56C6C';
  if (severity === 'WARNING') return 'color: #E6A23C';
  if (severity === 'OK')      return 'color: #67C23A';
  return 'color: #909399';
}

function severityIcon(severity: string): string {
  if (severity === 'ERROR')   return 'el-icon-error';
  if (severity === 'WARNING') return 'el-icon-warning';
  if (severity === 'OK')      return 'el-icon-success';
  return 'el-icon-info';
}

function messageText(row: DiagnosticEntry): string {
  const key = `jifa.threadDump.diagnosis.type.${row.type}`;
  const count: number = row.params?.count ?? 0;
  return t(key, count, row.params);
}

function suggestionText(row: DiagnosticEntry): string {
  return t(`jifa.threadDump.diagnosis.type.${row.type}_SUGGESTION`);
}

function examineThreads(row: DiagnosticEntry) {
  if (Array.isArray(row.threads) && row.threads.length > 0) {
    selectedThreadIds.value = row.threads.map((th) => th.id);
    threadDialogVisible.value = true;
  }
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div v-loading="loading">
    <el-table
      :data="diagnostics"
      stripe
      style="width: 100%"
    >
      <!-- Message column -->
      <el-table-column :label="tdt('diagnosis.messageColumn')" min-width="280">
        <template #default="{ row }">
          <i
            :style="severityColor(row.severity)"
            :class="severityIcon(row.severity)"
            :title="row.severity"
          />
          <span style="margin-left: 10px">{{ messageText(row) }}</span>
        </template>
      </el-table-column>

      <!-- Suggestion column -->
      <el-table-column :label="tdt('diagnosis.suggestionColumn')">
        <template #default="{ row }">
          <span>{{ suggestionText(row) }}</span>
          <el-button
            v-if="Array.isArray(row.threads) && row.threads.length > 0"
            type="primary"
            link
            style="margin-left: 8px"
            @click="examineThreads(row)"
          >
            {{ tdt('diagnosis.examine') }}
          </el-button>
        </template>
      </el-table-column>
    </el-table>

    <!-- Thread detail dialog -->
    <el-dialog v-model="threadDialogVisible" width="80%">
      <Thread :ids="selectedThreadIds" />
    </el-dialog>
  </div>
</template>

<style scoped>
:deep(.el-table .cell) {
  word-break: break-word !important;
  font-size: larger;
}
:deep(.el-table .el-button) {
  font-size: medium;
}
</style>
