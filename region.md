# Cómo evitar que las Regiones muevan el Audio

Por defecto, en Reaper, si arrastras una región desde su barra superior (el encabezado), Reaper entiende que quieres **mover todo ese bloque de tiempo**, incluyendo los clips de audio que haya debajo.

Para evitar esto y solo ajustar la duración o posición de la "etiqueta" de la región, tienes dos opciones:

## Opción 1: Mover solo los bordes (Recomendado)
En lugar de hacer clic en el centro de la barra de la región:
1.  Coloca el ratón en el **borde izquierdo o derecho** de la región (en la regla de tiempo).
2.  El cursor cambiará a una flecha doble `<->`.
3.  Arrastra para cambiar el inicio o el final.
    *   *Esto nunca mueve el audio, solo estira o encoge la región.*

## Opción 2: Cambiar el comportamiento del ratón (Definitivo)
Si quieres poder arrastrar la región entera sin que se lleve el audio, puedes cambiar la configuración:

1.  Ve al menú **Options** -> **Preferences** (o pulsa `Ctrl + P`).
2.  En la lista de la izquierda, busca **Mouse Modifiers** (hacia abajo).
3.  En los desplegables de arriba, selecciona:
    *   Context: **Ruler marker/region lane**
    *   Event: **Left drag**
4.  Verás que la acción "Default action" está puesta en **"Move region"** (esto es lo que mueve el audio).
5.  Haz doble clic sobre "Move region" y cámbialo a:
    *   **"Move region edge"** (así, aunque pinches en el centro, solo moverá el borde más cercano).
    *   O selecciona **"No action"** (para que no haga nada si pinchas en el centro, obligándote a ir a los bordes).
6.  Dale a **Apply** y **OK**.

Ahora, si intentas arrastrar una región desde el centro, ya no moverá tus pistas de audio por accidente.
