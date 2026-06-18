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
import Thread from '@/components/threaddump/Thread.vue';

const { request } = useAnalysisApiRequester();
const { t } = useI18n();

const loading = ref(false);

interface VThread {
  id: number;
  name: string;
}

interface VBlockingThread {
  blockingThread: VThread;
  blockedThreads: VThread[];
  heldLock?: {
    id: number;
    address: number;
    class: string;
    classInstance: boolean;
    state: string;
  } | null;
}

const blockingThreads = ref<VBlockingThread[]>([]);

// Thread detail dialog
const threadDialogVisible = ref(false);
const selectedIds = ref<number[]>([]);

function openThread(ids: number[]) {
  selectedIds.value = ids;
  threadDialogVisible.value = true;
}

function blockedTitle(bt: VBlockingThread): string {
  return t('jifa.threadDump.blockedThreads.title', bt.blockedThreads.length, {
    blocker: bt.blockingThread.name,
    count: bt.blockedThreads.length
  });
}

function loadData() {
  loading.value = true;
  request('blockingThreads', {}).then((data: VBlockingThread[]) => {
    blockingThreads.value = data;
    loading.value = false;
  });
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div v-loading="loading">
    <div v-if="blockingThreads.length === 0 && !loading" style="color: #909399; padding: 8px 0">
      {{ tdt('diagnosis.type.NO_ISSUES') }}
    </div>

    <el-collapse v-else accordion>
      <el-collapse-item
        v-for="(bt, idx) in blockingThreads"
        :key="idx"
        :name="idx"
      >
        <template #title>
          <span class="clickable" @click.stop="openThread([bt.blockingThread.id])">
            {{ blockedTitle(bt) }}
          </span>
        </template>

        <!-- Blocking thread -->
        <div style="margin-bottom: 8px">
          <el-tag type="danger" style="margin-right: 6px">Blocking</el-tag>
          <span
            class="clickable"
            @click="openThread([bt.blockingThread.id])"
          >{{ bt.blockingThread.name }}</span>
          <span v-if="bt.heldLock" style="color: #909399; margin-left: 8px; font-size: 12px">
            locked {{ bt.heldLock.class }}
          </span>
        </div>

        <!-- Blocked threads -->
        <el-tag
          v-for="blocked in bt.blockedThreads"
          :key="blocked.id"
          type="warning"
          style="margin: 2px 4px 2px 0; cursor: pointer"
          @click="openThread([blocked.id])"
        >
          {{ blocked.name }}
        </el-tag>
      </el-collapse-item>
    </el-collapse>

    <el-dialog v-model="threadDialogVisible" width="80%">
      <Thread :ids="selectedIds" />
    </el-dialog>
  </div>
</template>

<style scoped>
:deep(.el-collapse-item__header) {
  font-size: 14px;
}
</style>
