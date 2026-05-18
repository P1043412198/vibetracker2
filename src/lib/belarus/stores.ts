/**
 * Список сетей-магазинов Беларуси с категорией по умолчанию —
 * чтобы при сохранении транзакции / товара можно было выбрать
 * магазин из пресета и автоматически получить категорию расхода.
 */

export interface BYStorePreset {
  id: string;
  name: string;
  category: string;
  /** Региональный/общеРБ. */
  scope: 'national' | 'minsk' | 'regional';
  url?: string;
}

export const BY_STORES: BYStorePreset[] = [
  // Продукты
  { id: 'evroopt', name: 'Евроопт', category: 'Продукты', scope: 'national', url: 'https://evroopt.by' },
  { id: 'sosedi', name: 'Соседи', category: 'Продукты', scope: 'national', url: 'https://sosedi.by' },
  { id: 'green', name: 'GREEN', category: 'Продукты', scope: 'national', url: 'https://greenmarket.by' },
  { id: 'gippo', name: 'Гиппо', category: 'Продукты', scope: 'national', url: 'https://gippo.by' },
  { id: 'santa', name: 'Санта', category: 'Продукты', scope: 'national', url: 'https://santa.by' },
  { id: 'korona', name: 'Корона', category: 'Продукты', scope: 'national' },
  { id: 'vitalur', name: 'Виталюр', category: 'Продукты', scope: 'minsk' },
  { id: 'svetofor', name: 'Светофор', category: 'Продукты', scope: 'national' },
  { id: 'dobronom', name: 'Доброном', category: 'Продукты', scope: 'national' },

  // Доставка
  { id: 'edostavka', name: 'Е-доставка', category: 'Продукты', scope: 'national', url: 'https://edostavka.by' },
  { id: 'yandexlavka', name: 'Яндекс Лавка', category: 'Продукты', scope: 'minsk' },

  // Электроника / маркетплейсы
  { id: '21vek', name: '21vek.by', category: 'Техника', scope: 'national', url: 'https://21vek.by' },
  { id: 'oz', name: 'OZ.by', category: 'Книги', scope: 'national', url: 'https://oz.by' },
  { id: 'kufar', name: 'Kufar', category: 'Прочее', scope: 'national', url: 'https://kufar.by' },
  { id: 'ozon-by', name: 'OZON', category: 'Прочее', scope: 'national', url: 'https://ozon.by' },
  { id: 'wildberries', name: 'Wildberries', category: 'Прочее', scope: 'national' },

  // Аптеки
  { id: 'planeta', name: 'Планета здоровья', category: 'Здоровье', scope: 'national' },
  { id: 'apteka-1', name: 'Аптека № 1', category: 'Здоровье', scope: 'national' },

  // Транспорт
  { id: 'minsktrans', name: 'Минсктранс', category: 'Транспорт', scope: 'minsk' },
  { id: 'metro', name: 'Метрополитен', category: 'Транспорт', scope: 'minsk' },
  { id: 'bzhd', name: 'БЖД (электричка)', category: 'Транспорт', scope: 'national' },
  { id: 'yandex-taxi', name: 'Яндекс Такси', category: 'Транспорт', scope: 'national' },
  { id: 'maxim', name: 'Maxim', category: 'Транспорт', scope: 'national' },
  { id: 'hello', name: 'Hello (каршеринг)', category: 'Транспорт', scope: 'minsk' },

  // АЗС
  { id: 'belorusneft', name: 'Белоруснефть', category: 'Авто', scope: 'national' },
  { id: 'a-100', name: 'А-100', category: 'Авто', scope: 'national' },
  { id: 'gazpromneft', name: 'Газпромнефть', category: 'Авто', scope: 'national' },
];
