# Load libraries
library(shiny)
library(shinydashboard) # dashboard layout
library(RSQLite) # self-contained SQL DB 
library(DBI) # to query DB
library(sf) # to read spatial data (shape, geoJSON)
library(dplyr) # for data manipulation (filter, select columns, etc.)
library(rgeoda) # for LISA analysis
library(leaflet) # to plot interactive map
library(ggplot2) # to plot static map
library(RColorBrewer)  # for YlOrBr color scale
library(classInt)  # provides natural break values
library(shinyWidgets) # provide shiny widgets (like range slider)
library(shinyjqui) # provide popup windows inside shiny
library(shinyjs)
library(base64enc)

# Global: Define sorted states
sorted_states <- c(
  "Acre" = "AC", "Alagoas" = "AL", "Amapá" = "AP", "Amazonas" = "AM",
  "Bahia" = "BA", "Ceará" = "CE", "Distrito Federal" = "DF", "Espírito Santo" = "ES",
  "Goiás" = "GO", "Maranhão" = "MA", "Mato Grosso" = "MT", "Mato Grosso do Sul" = "MS",
  "Minas Gerais" = "MG", "Pará" = "PA", "Paraíba" = "PB", "Paraná" = "PR",
  "Pernambuco" = "PE", "Piauí" = "PI", "Rio de Janeiro" = "RJ", "Rio Grande do Norte" = "RN",
  "Rio Grande do Sul" = "RS", "Rondônia" = "RO", "Roraima" = "RR", "Santa Catarina" = "SC",
  "São Paulo" = "SP", "Sergipe" = "SE", "Tocantins" = "TO"
)

# Encode the image to Base64
image_base64 <- base64encode("www/partners.jpg")

# App UI
ui <- dashboardPage(
    skin = "purple",
    
    dashboardHeader(title = "Painel de Análise 1.1.0-demo"),
    
    dashboardSidebar(
        useShinyjs(),
        
        sidebarMenu(
            menuItem("Análise LISA", tabName = "lisa_indx", icon = icon("chart-bar")),
            
            selectInput("var_type", "Seleccione o tipo de indicador:", choices = c("Saúde", "Ambiental")),
            uiOutput("var_select"),
            uiOutput("year_select"),
            
            selectInput(
                "region", 
                "Seleccione a região(UF):",
                choices = sorted_states
            ),
            
            actionButton("run_lisa", "Ver mapa de clusters (LISA Map)"),
            
            # Caption above the image
            tags$div(
                style = "text-align: center; margin-bottom: 5px;",  
                tags$strong("Nossos Parceiros")  # Bold caption text
            ),
            
            # Image placed below the action button
            tags$div(
                style = "text-align: center; padding: 10px;",  # Center and add spacing
                tags$img(
                    src = paste0("data:image/jpeg;base64,", image_base64),
                    style = "max-width: 100%; height: auto; border-radius: 5px;",  # Ensure it fits the container
                    alt = "Sidebar Image"    # Alternative text for accessibility
                )
            )
        )
    ),  # dashboardSidebar closing
    
    
    dashboardBody(
        tags$head(
            tags$link(
                rel = "stylesheet", 
                href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/css/all.min.css"
            )
        ),
        
        tabItems(
            tabItem(
                tabName = "lisa_indx",
                tabBox(
                    width = 12,
                    
                    # First tabPanel: "Mapas"
                    tabPanel(
                        "Mapas",
                        fluidRow(
                            box(
                                title = "Mapa de Clusters e Outliers Espaciais",
                                status = "primary",
                                solidHeader = TRUE,
                                width = 12,
                                htmlOutput("map_info"),
                                leafletOutput("lisa_map"),
                                htmlOutput("map_legend")
                            )
                        ),
                        fluidRow(
                            box(
                                id = "visualization_options",
                                title = "Download de Mapas Gerados",
                                status = "primary",
                                solidHeader = TRUE,
                                width = 12,
                                div(
                                    style = "display: flex; justify-content: space-between; align-items: center;",
                                    checkboxInput("clus_map", "Mapa de clusters (LISA map)", value = TRUE),
                                    checkboxInput("tmc_map", "Mapa temático", value = FALSE),
                                    checkboxInput("p_map", "Mapa de significância estatística (p-value)", value = FALSE),
                                    actionButton("apply_options", "Gerar Mapas")
                                ),
                                plotOutput("static_map_output", height = "600px"),
                                downloadButton("download_map", "Baixar Mapa como PNG")
                            )
                        ),
                        
                    ),
                    
                    # Second tabPanel: "Sobre a plataforma"
                    tabPanel(
                        "Sobre a plataforma",
                        icon = icon("info-circle"),
                        fluidRow(
                            box(
                                title = "Metodologia Estatística",
                                status = "info",
                                solidHeader = TRUE,
                                width = 6,
                                htmlOutput("page_info")
                            )
                        )
                    )
                )
            )
        ),
        
        # Floating Thematic Map (Updated Aesthetics)
        jqui_draggable(
            jqui_resizable(
                div(
                    id = "floating_map",
                    style = "position: absolute; top: 180px; right: 20px; width: 400px; height: 400px; z-index: 999;
                   background: rgba(255, 255, 255, 0.9); padding: 5px; border-radius: 10px;
                   box-shadow: 0px 0px 5px rgba(0,0,0,0.3); display: none;",  # Initially Hidden
                    div(
                        style = "display: flex; justify-content: space-between; align-items: center; cursor: grab;
                     background: #3c8dbc; color: white; padding: 5px; border-radius: 10px 10px 0 0;",
                        tags$i(class = "fas fa-arrows-alt", style = "font-size: 18px; margin-right: 10px;"),
                        span("Mapa Temático", style = "font-size: 14px; font-weight: bold;"),
                        actionButton(
                            "close_map", "X", 
                            class = "btn btn-light btn-sm",
                            style = "padding: 2px 6px; font-weight: bold; font-size: 14px; color: black;"
                        )
                    ),
                    leafletOutput("natural_breaks_map", height = "350px", width = "100%")
                )
            )
        ),
        
        # JavaScript for Hover Effects
        tags$script(HTML("
      $(document).on('mouseenter', '#close_map', function() {
        $(this).css('background-color', 'red').css('color', 'white');
      }).on('mouseleave', '#close_map', function() {
        $(this).css('background-color', 'white').css('color', 'black');
      });
    ")),
        
        # Leaflet Map Setup with Adjusted Zoom Level
        tags$script(HTML("
      $(document).ready(function() {
        Shiny.addCustomMessageHandler('setView', function(data) {
          var map = window.L.DomUtil.get('natural_breaks_map')._leaflet_map;
          map.setView([data.lat, data.lng], data.zoom);
        });
      });
    "))
    )
)

# App server
server <- function(input, output, session) {
    useShinyjs()  # Ensure shinyjs is initialized
    
    # Initialize the map with Brazil's location
    output$lisa_map <- renderLeaflet({
        leaflet() %>%
            addTiles() %>%
            setView(lng = -51.9253, lat = -14.2350, zoom = 3) # Coordinates for Brazil
    })
    
    # Render HTML boxes in the "Mapas" tab
    output$map_info <- renderUI({
        HTML("<div style='border: 1px solid black; padding: 10px; padding: 5px;'>
            <h4>Considerações para a interpretação dos mapas</h4>
            <p>As áreas de <b>cor vermelha</b> representam altas taxas do indicador ambiental ou de saúde analisado. 
            As áreas de <b>cor azul</b> representam áreas onde as taxas do indicador analisado permanecem baixas.</p>
         </div>")
    })
    
    output$map_legend <- renderUI({
        HTML("<div style='border: 1px solid black; padding: 10px; padding: 5px;'>
            <p>Este aplicativo utiliza dados coletados do Painel de Informações do <a href='https://mapas.climaesaude.icict.fiocruz.br/' target='_blank'>
            Observatório de Clima e Saúde (Icict/Fiocruz)</a>.</p>
         </div>")
    })
    
    output$page_info <- renderUI({
        HTML("<div style='border: 1px solid black; padding: 10px;'>
            <h4>Página em construção.</h4>
         </div>")
    })
    
    # Connect to SQLite database
    db <- dbConnect(RSQLite::SQLite(), "data/db_indx.sqlite")
    
    onStop(function() {
        dbDisconnect(db)
        message("Database connection closed.")
    })
    
    # Dynamic UI: Update variable selection based on category
    output$var_select <- renderUI({
        if (input$var_type == "Saúde") {
            selectInput("variable", "Seleccione um indicador de saúde:", choices = c("Dengue" = "DENV", "Zika virus" = "ZIKV"))
        } else if (input$var_type == "Ambiental") {
            selectInput("variable", "Seleccione um indicador ambiental:", choices = c("Concentração de Material Particulado" = "PM"))
        }
    })
    
    # Dynamic UI: Update year selection based on chosen variable
    output$year_select <- renderUI({
        req(input$variable)
        query <- "SELECT name FROM pragma_table_info('indx_geojson')"
        col_names <- dbGetQuery(db, query)$name
        matching_cols <- grep(paste0("^", input$variable, "_"), col_names, value = TRUE)
        selectInput("lisa_year", "Selecione o ano:", choices = matching_cols)
    })
    
    # Create a reactiveValues object to store data for reuse
    lisa_data <- reactiveValues(spatial_data = NULL, lisa_result = NULL)
    
    # Store generated static maps
    generated_maps <- reactiveValues(cluster = NULL, thematic = NULL, pvalue = NULL)
    
    # Run LISA Analysis when button is clicked
    observeEvent(input$run_lisa, {
        req(input$lisa_year)
        
        query <- sprintf("SELECT * FROM indx_geojson WHERE SIGLA_UF = '%s'", input$region)
        spatial_data <- st_read(db, query = query)
        
        if (nrow(spatial_data) == 0) {
            showNotification("Nenhum dado encontrado para a região selecionada.", type = "error")
            return()
        }
        
        # Transform spatial data
        spatial_data <- st_transform(spatial_data, crs = 4326)
        
        # Set variable prefix
        var_name <- input$lisa_year
        if (!(var_name %in% colnames(spatial_data))) {
            showNotification(paste("Coluna", var_name, "não encontrada nos dados."), type = "error")
            return()
        }
        
        # Create weight matrix using rgeoda
        w <- queen_weights(spatial_data)
        
        # Run LISA analysis
        lisa_result <- local_moran(w, as.data.frame(spatial_data[var_name]))
        
        # Extract LISA data
        spatial_data$lisa_clusters <- lisa_clusters(lisa_result, cutoff = 0.05)
        spatial_data$lisa_pvalues <- lisa_pvalues(lisa_result)
        
        # Define LISA labels corresponding to the numeric cluster values
        lisa_labels_map <- c("Não significativo",          # 0
                             "Hot-Spot Cluster",          # 1
                             "Cold-Spot Cluster",         # 2
                             "Outlier Espacial (baixo-alto)",  # 3
                             "Outlier Espacial (alto-baixo)")  # 4
        
        # Assign text labels based on cluster values
        spatial_data$lisa_labels <- sapply(spatial_data$lisa_clusters, function(x) lisa_labels_map[x + 1])
        
        # Define colors for clusters
        lisa_colors <- c("#F0F0F0", "#FF0000", "#0000FF", "#9e9ac8", "#f768a1")
        spatial_data$color <- sapply(spatial_data$lisa_clusters, function(x) lisa_colors[x + 1])
        
        # Store lisa data for statics maps
        lisa_data$spatial_data <- spatial_data
        lisa_data$lisa_result <- lisa_result
        
        # Extract region & year for legend
        selected_region <- names(which(sorted_states == input$region))
        selected_year <- sub("^.*_(\\d{4})$", "\\1", input$lisa_year)
        
        # Create legend title for thematic map
        legend_title_tm <- switch(input$variable,
                                  "DENV" = paste("Taxa de incidência de dengue por 100 mil hab.,", selected_region, "-", selected_year),
                                  "ZIKV" = paste("Taxa de incidência de zika vírus por 100 mil hab.,", selected_region, "-", selected_year),
                                  "PM" = paste("Concentração de material particulado fino na atmosfera (PM),", selected_region, "-", selected_year))
        
        # Create custom label for thematic map
        label_tm <- switch(input$variable,
                           "DENV" = paste(" - Taxa de incidência por 100 mil hab.:"),
                           "ZIKV" = paste(" - Taxa de incidência por 100 mil hab.:"),
                           "PM" = paste(" - Concentração de PM(µm):"))
        
        # Create legend title for lisa map
        legend_title_lis <- switch(input$variable,
                                   "DENV" = paste("Clusters detectados,", selected_region, "-", selected_year),
                                   "ZIKV" = paste("Clusters detectados,", selected_region, "-", selected_year),
                                   "PM" = paste("Clusters detectados,", selected_region, "-", selected_year))
        
        # Render LISA map
        output$lisa_map <- renderLeaflet({
            leaflet(spatial_data) %>%
                addTiles() %>%
                addPolygons(
                    fillColor = ~color,
                    color = "#333333",
                    weight = 0.2,
                    opacity = 1,
                    fillOpacity = 0.7,
                    # Label for the hovered polygon
                    label = ~NM_MUN,  # Only display the city name 
                    # Configure label options for hover
                    labelOptions = labelOptions(
                        textsize = "15px",   # Label text size
                        direction = "auto",  # Automatically position the label
                        opacity = 0.9,       # Slightly transparent label
                        style = list(
                            "background" = "white",  # White background for better readability
                            "border" = "1px solid black",
                            "padding" = "5px",
                            "font-weight" = "bold",
                            "color" = "#333"
                        ),
                        sticky = FALSE,  # Ensure the label disappears when not hovering
                        html = FALSE     # Do not interpret HTML for now
                    )
                ) %>%
                # Dynamic Legend Title
                addLegend(position = "bottomleft", colors = lisa_colors, labels = c("Não Significativo", "Hot-Spot Cluster", "Cold-Spot Cluster", "Outlier Espacial", "Outlier Espacial"), title = legend_title_lis)
        })
        
        # Show floating thematic map
        shinyjs::show("floating_map")
        
        # Reactive expression to handle map updates only when "run_lisa" is clicked
        map_data <- eventReactive(input$run_lisa, {
            var_col <- paste0(input$variable, "_", sub("^.*_(\\d{4})$", "\\1", input$lisa_year))
            req(var_col %in% colnames(spatial_data))
            
            # Calculate natural breaks classification
            breaks_values <- classIntervals(spatial_data[[var_col]], n = 5, style = "jenks")$brks
            
            list(
                var_col = var_col,
                breaks_values = breaks_values
            )
        })
        
        # Render floating thematic map
        output$natural_breaks_map <- renderLeaflet({
            req(map_data())  # Ensure map_data is available
            
            var_col <- map_data()$var_col
            breaks_values <- map_data()$breaks_values
            
            # Define color palette
            palette <- colorBin("YlOrBr", domain = spatial_data[[var_col]], bins = breaks_values, na.color = "gray")
            
            # Render floating thematic map
            leaflet(spatial_data) %>%
                addTiles() %>%
                addPolygons(
                    fillColor = ~palette(spatial_data[[var_col]]),
                    color = "black",
                    weight = 1,
                    fillOpacity = 0.7,
                    label = ~paste0(NM_MUN, label_tm, spatial_data[[var_col]])
                ) %>%
                addLegend(pal = palette, values = spatial_data[[var_col]], title = legend_title_tm, position = "bottomright")
        })
    })
    
    # Close floating thematic map when clicking the "X" button
    observeEvent(input$close_map, {
        shinyjs::hide("floating_map")
    })
    
    # Generate Static Maps when "Gerar Mapas" is clicked
    observeEvent(input$apply_options, {
        req(lisa_data$spatial_data)
        
        spatial_data <- lisa_data$spatial_data
        plots <- list()
        
        # Extract region & year for legend
        selected_region <- names(which(sorted_states == input$region))  # Dynamically retrieve the selected region
        selected_year <- sub("^.*_(\\d{4})$", "\\1", input$lisa_year)  # Extract the year from input$lisa_year
        
        # Define a mapping of numeric LISA clusters to meaningful labels
        lisa_labels_map <- c("1" = "Hot-Spot Cluster", 
                             "2" = "Cold-Spot Cluster", 
                             "3" = "Outlier Espacial (baixo-alto)", 
                             "4" = "Outlier Espacial (alto-baixo)")
        
        # Convert numeric clusters to factor labels
        spatial_data$lisa_clusters <- factor(spatial_data$lisa_clusters, 
                                             levels = c(1, 2, 3, 4),
                                             labels = c("Hot-Spot Cluster (alto-alto)", 
                                                        "Cold-Spot Cluster (baixo-baixo)", 
                                                        "Outlier Espacial (baixo-alto)", 
                                                        "Outlier Espacial (alto-baixo)"))
        
        # Assign "Não significativo" to regions with NA values
        spatial_data$lisa_clusters <- as.character(spatial_data$lisa_clusters)  # Temporarily convert to character
        spatial_data$lisa_clusters[is.na(spatial_data$lisa_clusters)] <- "Não significativo"  # Assign label to NA
        spatial_data$lisa_clusters <- factor(spatial_data$lisa_clusters)  # Convert back to factor
        
        # Define colors, including white for non-clustered areas
        lisa_colors <- c("Hot-Spot Cluster (alto-alto)" = "#FF0000", 
                         "Cold-Spot Cluster (baixo-baixo)" = "#0000FF", 
                         "Outlier Espacial (baixo-alto)" = "#9e9ac8", 
                         "Outlier Espacial (alto-baixo)" = "#f768a1",
                         "Não significativo" = "#F0F0F0")  # Background color
        
        # Create dynamic title and subtitle
        clus_map_title <- "Mapa de Clusters e Outliers Espaciais"
        clus_map_subtitle <- switch(input$variable,
                                    "DENV" = paste("Taxa de incidência de dengue por 100 mil hab.,", selected_region, "-", selected_year),
                                    "ZIKV" = paste("Taxa de incidência de virus zika por 100 mil hab.,", selected_region, "-", selected_year),
                                    "PM" = paste("Concentração de Material Particulado fino na atmosfera (PM)", selected_region, "-", selected_year))
        
        # Generate Cluster Map
        if (input$clus_map) {
            cluster_plot <- ggplot(spatial_data) +
                geom_sf(aes(fill = lisa_clusters), color = "black") +  # Use meaningful labels
                scale_fill_manual(values = lisa_colors, 
                                  name = "LISA Clusters") +  # Legend update
                labs(
                    title = clus_map_title,            
                    subtitle = clus_map_subtitle,
                    caption = "Fonte dos dados: Observatório do Clima e Saúde | Icict/Fiocruz"
                ) +
                theme_void()
            
            # Store plot in reactive values
            generated_maps$cluster <- cluster_plot
            plots$cluster <- cluster_plot
        }
        
        if (input$tmc_map) {
            # Load necessary library for natural breaks classification
            library(classInt)
            
            # Extract the selected year variable
            thematic_variable <- spatial_data[[input$lisa_year]]
            
            # Classify the variable using natural breaks
            natural_breaks <- classIntervals(thematic_variable, n = 5, style = "jenks")  # 5 classes with natural breaks
            spatial_data$classified_var <- cut(thematic_variable, 
                                               breaks = natural_breaks$brks, 
                                               include.lowest = TRUE, 
                                               dig.lab = 10)  # Create a factor column with classes
            
            # Generate the thematic map
            thematic_plot <- ggplot(spatial_data) +
                geom_sf(aes(fill = classified_var), color = "black") +  # Use classified variable for fill
                scale_fill_brewer(palette = "YlOrBr", name = "Taxa de Incidência por 100 mil hab.") +  # Use YlOrBr color palette
                labs(
                    title = "Mapa Temático",       
                    subtitle = clus_map_subtitle,
                    caption = "Fonte dos dados: Observatório do Clima e Saúde | Icict/Fiocruz"
                ) +
                theme_void()
            
            # Store the generated plot
            generated_maps$thematic <- thematic_plot
            plots$thematic <- thematic_plot
        }
        
        if (input$p_map) {
            # Classify p-values into categories
            spatial_data$pvalue_categories <- cut(
                spatial_data$lisa_pvalues,
                breaks = c(-Inf, 0.001, 0.01, 0.05, Inf),  # Define breakpoints for classification
                labels = c("p <= 0.001", "p <= 0.01", "p <= 0.05", "Não significativo"),  # Labels for categories
                include.lowest = TRUE  # Include lowest value in the first category
            )
            
            # Define colors for the categories
            pvalue_colors <- c(
                "Não significativo" = "#eeeeee",  # Light gray
                "p <= 0.05" = "#84f576",        # Light green
                "p <= 0.01" = "#53c53c",        # Medium green
                "p <= 0.001" = "#348124"        # Dark green
            )
            
            # Create the p-value plot
            pvalue_plot <- ggplot(spatial_data) +
                geom_sf(aes(fill = pvalue_categories), color = "black") +  # Use categorized p-values
                scale_fill_manual(values = pvalue_colors, name = "P-value") +  # Use the defined colors and legend name
                labs(
                    title = "Mapa de Significância Estatística (Análise LISA)",  # Title
                    subtitle = clus_map_subtitle,
                    caption = "Fonte dos dados: Observatório do Clima e Saúde | Icict/Fiocruz"
                )+
                theme_void()
            
            # Store the generated plot
            generated_maps$pvalue <- pvalue_plot
            plots$pvalue <- pvalue_plot
        }
        
        output$static_map_output <- renderPlot({
            if (length(plots) > 0) {
                gridExtra::grid.arrange(grobs = plots, ncol = 2)
            } else {
                showNotification("Selecione pelo menos um tipo de mapa.", type = "warning")
            }
        })
    })
    
    # Download Map as PNG
    output$download_map <- downloadHandler(
        filename = function() {
            paste0("LISA_Map_", Sys.Date(), ".png")
        },
        content = function(file) {
            plot_list <- list()
            if (!is.null(generated_maps$cluster)) plot_list$cluster <- generated_maps$cluster
            if (!is.null(generated_maps$thematic)) plot_list$thematic <- generated_maps$thematic
            if (!is.null(generated_maps$pvalue)) plot_list$pvalue <- generated_maps$pvalue
            
            ggsave(file, plot = gridExtra::marrangeGrob(grobs = plot_list, ncol = 2, nrow = 2), width = 10, height = 8)
        }
    )
}

# Run App
shinyApp(ui, server)