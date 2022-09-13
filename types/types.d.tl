global record vim
  record o
    lines: integer
    columns: integer
  end

  record keymap
    record SetOption
      buffer: integer|boolean
    end
    set: function(string|{string}, string, function()|string, SetOption)
  end

  record fn
    record Tag
      name: string
      filename: string
      cmd: string
      kind: string
      static: string
    end

    taglist: function(string, string|nil): {Tag}
    pumvisible: function(): integer
    match: function(string|{string}, string, integer, integer): integer
    mode: function(): string
    getcwd: function(): string
    reverse: function<T>({T}): {T}
  end

  record api

    record SetHlOptions
      link: string
      default: boolean
      bg: string
    end

    record OpenWinOptions
      relative: string
      win: WinNr|nil
      anchor: string|nil
      width: integer
      height: integer
      bufpos: {integer,integer}
      row: integer
      col: integer
      focusable: boolean
      external: boolean
      zindex: integer|nil
      style: string|nil
      border: string|nil
      noautocmd: boolean
    end

    record CreateAugroupOptions
      clear: boolean
    end

    record CreateAutocmdOptions
      group: string|integer|nil
      pattern: string|{string}|nil
      buffer: BufNr|nil
      desc: string|nil
      callback: function()|string|nil
      command: string|nil
      once: boolean|nil
      nested: boolean|nil
    end

    type BufNr = integer
    type WinNr = integer
    type NSId = integer

    nvim_feedkeys: function(string, string, boolean)
    nvim_err_writeln: function(string)
    nvim_get_current_buf: function(): integer
    nvim_get_current_line: function(): string
    nvim_replace_termcodes: function(string, boolean, boolean, boolean): string
    nvim_set_option: function(string, any)
    nvim_get_option: function(string): any
    nvim_get_vvar: function(string): any

    nvim_create_augroup: function(string, CreateAugroupOptions)
    nvim_create_autocmd: function(string|{string}, CreateAutocmdOptions)

    nvim_create_namespace: function(string): NSId

    nvim_create_buf: function(boolean, boolean): BufNr
    nvim_buf_get_option: function(BufNr, string): any
    nvim_buf_get_lines: function(BufNr, integer, integer, boolean): {string}
    nvim_buf_set_lines: function(BufNr, integer, integer, boolean, {string})
    nvim_buf_set_text: function(BufNr, integer, integer, integer, integer, {string})
    nvim_buf_add_highlight: function(BufNr, NSId, string, integer, integer, integer)
    nvim_buf_clear_namespace: function(BufNr, NSId, integer, integer)

    nvim_open_win: function(BufNr, boolean, OpenWinOptions): WinNr
    nvim_win_close: function(WinNr, boolean)
    nvim_win_set_buf: function(WinNr, BufNr)
    nvim_win_set_option: function(WinNr, string, any)
    nvim_win_set_cursor: function(WinNr, {integer, integer})
    nvim_win_get_cursor: function(WinNr): {integer, integer}
    nvim_win_is_valid: function(WinNr): boolean
  end

  record lsp

    record LspPosition
      line: integer
      character: integer
    end

    record LspRange
      start: LspPosition
      ["end"]: LspPosition
    end

    record LspTextEdit
      range: LspRange
      newText: string
    end

    record LspCompletionItem
      label: string
      detail: string|nil
      textEdit: LspTextEdit
      insertTextFormat: integer|nil
      insertText: string|nil
      additionalTextEdits: {LspTextEdit}
      kind: integer
    end

    record LspResult
      result: any
      err: string|nil
    end

    record LspClient
      request_sync: function(string, any, integer, integer): LspResult
      offset_encoding: string|nil
      record server_capabilities
        record completionProvider
          resolveProvider: boolean
        end
      end
    end


    record util
      apply_text_edits: function({LspTextEdit}, integer, string)
      make_position_params: function(): any
      extract_completion_items: function(any): {LspCompletionItem}
    end

    record protocol
      CompletionItemKind: {integer:string}
    end

    buf_request_sync: function(integer, string, any): {integer:LspResult}, string|nil
    get_client_by_id: function(integer): LspClient
  end

  record loop
    record FSIterator
    end
    fs_scandir: function(string): FSIterator
    fs_scandir_next: function(FSIterator): string|nil, string
  end

  record treesitter
    record TSTree
    end

    record TSNode
      named_descendant_for_range: function(TSNode, integer, integer, integer, integer): TSNode
      type: function(TSNode): string
    end

    record TSQuery
      captures: {integer: string}

      iter_captures: function(TSQuery, TSNode, integer, integer|nil, integer|nil, integer|nil, integer|nil): function(): integer, TSNode
    end

    record query
      get_node_text: function(TSNode, integer|nil): string
    end

    parse_query: function(string, string): TSQuery
  end

  schedule: function(function())
  startswith: function(string, string): boolean
  endswith: function(string, string): boolean
  str_byteindex: function(string, integer, boolean|nil): integer

  tbl_deep_extend: function(string, ...: table): table
  tbl_map: function<T, K>((function(T): K), {T}): {K}
  tbl_filter: function<T>((function(T): boolean), {T}): {T}
  tbl_filter: function<T>({T}, T): boolean

  list_extend: function<T>({T}, {T}, integer|nil, integer|nil): {T}

  notify: function(string)
  pretty_print: function(...: any)
  inspect: function(...: any): string
end

global record jit
  os: string
end
