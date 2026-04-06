-- Block documents: file attachments (PDFs, images) tied to a block.
-- Shared with all trip members. No private documents.

create table public.block_documents (
    id             uuid primary key default gen_random_uuid(),
    block_id       uuid not null references public.blocks(id) on delete cascade,
    user_id        uuid not null references public.users(id) on delete cascade,
    file_name      text not null,
    file_type      text not null check (file_type in ('pdf', 'image')),
    storage_path   text,
    upload_status  text not null default 'queued' check (upload_status in ('queued', 'uploading', 'uploaded', 'failed')),
    file_size      integer,
    created_at     timestamptz not null default now()
);

create index idx_block_documents_block on public.block_documents(block_id);

-- RLS: only trip members can access
alter table public.block_documents enable row level security;

create policy "block_documents_select" on public.block_documents
    for select to authenticated
    using (public.is_trip_member(public.trip_id_for_block(block_id)));

create policy "block_documents_insert" on public.block_documents
    for insert to authenticated
    with check (
        user_id = auth.uid()
        and public.is_trip_member(public.trip_id_for_block(block_id))
    );

create policy "block_documents_update" on public.block_documents
    for update to authenticated
    using (user_id = auth.uid());

create policy "block_documents_delete" on public.block_documents
    for delete to authenticated
    using (user_id = auth.uid());
