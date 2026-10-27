import type { ReactNode } from 'react';
import {
  DndContext, KeyboardSensor, PointerSensor, closestCenter, useSensor, useSensors, type DragEndEvent,
} from '@dnd-kit/core';
import {
  SortableContext, arrayMove, sortableKeyboardCoordinates, useSortable, verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { useTranslation } from 'react-i18next';

/**
 * Table body whose rows can be reordered by dragging the handle (mouse, touch or keyboard:
 * focus the handle, Space to pick up, arrows to move, Space to drop).
 */
export default function SortableRows<T>({ rows, getId, onReorder, children, className }: {
  rows: T[];
  getId: (row: T) => string;
  onReorder: (ordered: T[]) => void;
  children: (row: T) => ReactNode;
  className?: (row: T) => string;
}) {
  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 4 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }),
  );

  const onDragEnd = ({ active, over }: DragEndEvent) => {
    if (!over || active.id === over.id) return;
    const from = rows.findIndex((r) => getId(r) === active.id);
    const to = rows.findIndex((r) => getId(r) === over.id);
    onReorder(arrayMove(rows, from, to));
  };

  return (
    <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
      <SortableContext items={rows.map(getId)} strategy={verticalListSortingStrategy}>
        <tbody>
          {rows.map((row) => (
            <SortableRow key={getId(row)} id={getId(row)} className={className?.(row)}>{children(row)}</SortableRow>
          ))}
        </tbody>
      </SortableContext>
    </DndContext>
  );
}

function SortableRow({ id, className, children }: { id: string; className?: string; children: ReactNode }) {
  const { t } = useTranslation();
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });
  return (
    <tr
      ref={setNodeRef}
      className={`${className ?? ''} ${isDragging ? 'dragging' : ''}`}
      style={{ transform: CSS.Translate.toString(transform), transition, position: 'relative', zIndex: isDragging ? 2 : undefined }}
    >
      <td className="handle" title={t('ui.dragHandle')} aria-label={t('ui.dragHandle')} {...attributes} {...listeners}>⠿</td>
      {children}
    </tr>
  );
}
