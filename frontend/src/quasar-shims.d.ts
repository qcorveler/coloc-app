export {}

declare module 'vue' {
  interface GlobalComponents {
    QAvatar: typeof import('quasar')['QAvatar']
    QBanner: typeof import('quasar')['QBanner']
    QBtn: typeof import('quasar')['QBtn']
    QBtnToggle: typeof import('quasar')['QBtnToggle']
    QCard: typeof import('quasar')['QCard']
    QCheckbox: typeof import('quasar')['QCheckbox']
    QDialog: typeof import('quasar')['QDialog']
    QFile: typeof import('quasar')['QFile']
    QForm: typeof import('quasar')['QForm']
    QImg: typeof import('quasar')['QImg']
    QInput: typeof import('quasar')['QInput']
    QItem: typeof import('quasar')['QItem']
    QItemLabel: typeof import('quasar')['QItemLabel']
    QItemSection: typeof import('quasar')['QItemSection']
    QLayout: typeof import('quasar')['QLayout']
    QList: typeof import('quasar')['QList']
    QMenu: typeof import('quasar')['QMenu']
    QPage: typeof import('quasar')['QPage']
    QPageContainer: typeof import('quasar')['QPageContainer']
    QSelect: typeof import('quasar')['QSelect']
    QSpinner: typeof import('quasar')['QSpinner']
  }
}
